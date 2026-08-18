// Thin macOS host wiring for the official Chromium Embedded Framework.
//
// CEF owns browser rendering, subprocesses, input, scrolling, page zoom and
// the Chromium runtime. This file only connects the documented CEF lifecycle
// to the existing AppKit event loop, embeds one CEF child view, and confines
// Session Canvas resources to one request context.
//
// The NSApplication category/swizzling portion is derived from official JCEF
// native/util_mac.mm at 6d3e8ca02cd3ec0af163086f9a79281beb0cc60e.
// Copyright (c) 2008-2013 Marshall A. Greenblatt. Portions Copyright (c)
// 2006-2009 Google Inc. Complete BSD terms are preserved in
// ThirdPartyNotices/Licenses/JCEF-6d3e8ca0-LICENSE.txt.

#import "EgakiumCEFBridge.h"

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <crt_externs.h>
#include <limits.h>
#include <sys/stat.h>
#include <unistd.h>

#include <algorithm>
#include <atomic>
#include <cctype>
#include <memory>
#include <string>
#include <vector>

#include "EgakiumCEFScheme.h"
#include "include/cef_app.h"
#include "include/cef_application_mac.h"
#include "include/cef_browser.h"
#include "include/cef_client.h"
#include "include/cef_command_line.h"
#include "include/cef_frame.h"
#include "include/cef_life_span_handler.h"
#include "include/cef_load_handler.h"
#include "include/cef_parser.h"
#include "include/cef_request_context.h"
#include "include/cef_request_handler.h"
#include "include/cef_resource_request_handler.h"
#include "include/cef_scheme.h"
#include "include/cef_stream.h"
#include "include/internal/cef_types_mac.h"
#include "include/wrapper/cef_helpers.h"
#include "include/wrapper/cef_library_loader.h"
#include "include/wrapper/cef_stream_resource_handler.h"
#include "tests/shared/browser/main_message_loop_external_pump.h"

namespace {

NSString *const kEgakiumCEFContextReadyNotification =
    @"EgakiumCEFContextReadyNotification";

NSString *g_initialization_error = nil;
dispatch_block_t g_shutdown_completion = nil;
bool g_shutdown_complete = false;
bool g_handling_send_event = false;
bool g_orderly_termination_pending = false;

class EgakiumCEFRuntime;
class CanvasClient;

bool IsAllowedCanvasScheme(const std::string& scheme) {
  return scheme == egakium_cef::kCanvasScheme || scheme == "about" ||
         scheme == "data" || scheme == "blob";
}

std::string SchemeForURL(const CefString& url) {
  CefURLParts parts;
  if (!CefParseURL(url, parts)) {
    return std::string();
  }
  return CefString(&parts.scheme).ToString();
}

bool ResolveCEFRootCachePath(std::string* path, std::string* failure) {
  NSArray<NSURL*>* cache_urls = [[NSFileManager defaultManager]
      URLsForDirectory:NSCachesDirectory
             inDomains:NSUserDomainMask];
  NSURL* cache_root = cache_urls.firstObject;
  if (!cache_root) {
    *failure = "The macOS user cache directory is unavailable for CEF.";
    return false;
  }
  NSURL* cef_root = [[cache_root
      URLByAppendingPathComponent:@"com.Vita0818.EgakiumMac"
                       isDirectory:YES]
      URLByAppendingPathComponent:@"CEF"
                       isDirectory:YES];
  NSError* directory_error = nil;
  if (![[NSFileManager defaultManager]
          createDirectoryAtURL:cef_root
   withIntermediateDirectories:YES
                    attributes:nil
                         error:&directory_error]) {
    *failure = "CEF could not create its product-specific cache root: " +
               std::string(directory_error.localizedDescription.UTF8String);
    return false;
  }
  *path = cef_root.fileSystemRepresentation;
  return true;
}

bool HasCanonicalRootPrefix(const std::string& path,
                            const std::string& root) {
  if (path == root) {
    return true;
  }
  return path.size() > root.size() &&
         path.compare(0, root.size(), root) == 0 &&
         path[root.size()] == '/';
}

bool CanonicalizeExistingPath(const std::string& path, std::string* output) {
  char resolved[PATH_MAX];
  if (path.empty() || realpath(path.c_str(), resolved) == nullptr) {
    return false;
  }
  *output = resolved;
  return true;
}

bool ValidateCanvasRootAndIndex(const std::string& requested_root,
                                const std::string& requested_index,
                                std::string* canonical_root,
                                std::string* relative_index,
                                std::string* failure) {
  struct stat root_lstat = {};
  if (lstat(requested_root.c_str(), &root_lstat) != 0 ||
      !S_ISDIR(root_lstat.st_mode) || S_ISLNK(root_lstat.st_mode)) {
    *failure = "The Session Canvas root is missing, not a directory, or a symlink.";
    return false;
  }

  std::string root;
  std::string index;
  if (!CanonicalizeExistingPath(requested_root, &root) ||
      !CanonicalizeExistingPath(requested_index, &index) ||
      !HasCanonicalRootPrefix(index, root) || index == root) {
    *failure = "The Session Canvas index is outside its canonical root.";
    return false;
  }

  struct stat index_lstat = {};
  struct stat index_stat = {};
  if (lstat(requested_index.c_str(), &index_lstat) != 0 ||
      S_ISLNK(index_lstat.st_mode) || stat(index.c_str(), &index_stat) != 0 ||
      !S_ISREG(index_stat.st_mode)) {
    *failure = "The Session Canvas index must be a regular, non-symlink file.";
    return false;
  }

  *canonical_root = root;
  *relative_index = index.substr(root.size() + 1);
  return true;
}

int HexValue(char value) {
  if (value >= '0' && value <= '9') {
    return value - '0';
  }
  if (value >= 'a' && value <= 'f') {
    return value - 'a' + 10;
  }
  if (value >= 'A' && value <= 'F') {
    return value - 'A' + 10;
  }
  return -1;
}

bool DecodeURLPathComponent(const std::string& encoded, std::string* decoded) {
  decoded->clear();
  decoded->reserve(encoded.size());
  for (size_t index = 0; index < encoded.size(); ++index) {
    unsigned char value = static_cast<unsigned char>(encoded[index]);
    if (value == '%') {
      if (index + 2 >= encoded.size()) {
        return false;
      }
      const int high = HexValue(encoded[index + 1]);
      const int low = HexValue(encoded[index + 2]);
      if (high < 0 || low < 0) {
        return false;
      }
      value = static_cast<unsigned char>((high << 4) | low);
      index += 2;
    }
    // Encoded separators, NUL and Windows-style separators never become
    // filesystem path syntax.
    if (value == 0 || value == '/' || value == '\\') {
      return false;
    }
    decoded->push_back(static_cast<char>(value));
  }
  return !decoded->empty() && *decoded != "." && *decoded != "..";
}

bool ResolveCanvasRequestPath(const std::string& root,
                              const CefString& request_url,
                              std::string* resolved_path) {
  CefURLParts parts;
  if (!CefParseURL(request_url, parts) ||
      CefString(&parts.scheme).ToString() != egakium_cef::kCanvasScheme ||
      CefString(&parts.host).ToString() != egakium_cef::kCanvasHost) {
    return false;
  }

  std::string encoded_path = CefString(&parts.path).ToString();
  if (encoded_path.empty() || encoded_path.front() != '/') {
    return false;
  }
  encoded_path.erase(encoded_path.begin());
  if (encoded_path.empty()) {
    return false;
  }

  std::string candidate = root;
  size_t cursor = 0;
  while (cursor < encoded_path.size()) {
    const size_t separator = encoded_path.find('/', cursor);
    const size_t length = separator == std::string::npos
                              ? encoded_path.size() - cursor
                              : separator - cursor;
    if (length == 0) {
      return false;
    }
    std::string decoded_component;
    if (!DecodeURLPathComponent(encoded_path.substr(cursor, length),
                                &decoded_component)) {
      return false;
    }
    candidate.push_back('/');
    candidate.append(decoded_component);

    struct stat component_lstat = {};
    if (lstat(candidate.c_str(), &component_lstat) != 0 ||
        S_ISLNK(component_lstat.st_mode)) {
      return false;
    }
    if (separator == std::string::npos) {
      break;
    }
    if (!S_ISDIR(component_lstat.st_mode)) {
      return false;
    }
    cursor = separator + 1;
  }

  std::string canonical_candidate;
  struct stat candidate_stat = {};
  if (!CanonicalizeExistingPath(candidate, &canonical_candidate) ||
      !HasCanonicalRootPrefix(canonical_candidate, root) ||
      canonical_candidate == root ||
      stat(canonical_candidate.c_str(), &candidate_stat) != 0 ||
      !S_ISREG(candidate_stat.st_mode)) {
    return false;
  }
  *resolved_path = canonical_candidate;
  return true;
}

std::string MimeTypeForPath(const std::string& path) {
  const size_t slash = path.find_last_of('/');
  const size_t dot = path.find_last_of('.');
  if (dot == std::string::npos ||
      (slash != std::string::npos && dot < slash) || dot + 1 >= path.size()) {
    return "application/octet-stream";
  }
  std::string extension = path.substr(dot + 1);
  std::transform(extension.begin(), extension.end(), extension.begin(),
                 [](unsigned char value) {
                   return static_cast<char>(std::tolower(value));
                 });
  CefString mime = CefGetMimeType(extension);
  return mime.empty() ? "application/octet-stream" : mime.ToString();
}

class CanvasSchemeHandlerFactory final : public CefSchemeHandlerFactory {
 public:
  explicit CanvasSchemeHandlerFactory(std::string canonical_root)
      : canonical_root_(std::move(canonical_root)) {}

  CefRefPtr<CefResourceHandler> Create(
      CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame,
      const CefString& scheme_name,
      CefRefPtr<CefRequest> request) override {
    CEF_REQUIRE_IO_THREAD();
    if (scheme_name != egakium_cef::kCanvasScheme ||
        request->GetMethod() != "GET") {
      return nullptr;
    }

    std::string path;
    if (!ResolveCanvasRequestPath(canonical_root_, request->GetURL(), &path)) {
      return nullptr;
    }

    CefRefPtr<CefStreamReader> stream = CefStreamReader::CreateForFile(path);
    if (!stream) {
      return nullptr;
    }
    CefResponse::HeaderMap headers;
    headers.insert(std::make_pair("Cache-Control", "no-store"));
    headers.insert(std::make_pair("X-Content-Type-Options", "nosniff"));
    return new CefStreamResourceHandler(200, "OK", MimeTypeForPath(path),
                                        headers, stream);
  }

 private:
  const std::string canonical_root_;

  IMPLEMENT_REFCOUNTING(CanvasSchemeHandlerFactory);
};

class EgakiumCEFRuntime final {
 public:
  static EgakiumCEFRuntime& Shared() {
    static EgakiumCEFRuntime runtime;
    return runtime;
  }

  bool Initialize(std::string* failure);

  bool IsAvailable() const {
    return initialized_ && !shutting_down_;
  }

  bool IsContextReady() const { return context_ready_; }

  void ContextInitialized() {
    CEF_REQUIRE_UI_THREAD();
    context_ready_ = true;
    [[NSNotificationCenter defaultCenter]
        postNotificationName:kEgakiumCEFContextReadyNotification
                      object:nil];
  }

  void RegisterBrowser(CefRefPtr<CefBrowser> browser) {
    CEF_REQUIRE_UI_THREAD();
    browsers_.push_back(browser);
    if (shutting_down_) {
      browser->GetHost()->CloseBrowser(true);
    }
  }

  void UnregisterBrowser(CefRefPtr<CefBrowser> browser) {
    CEF_REQUIRE_UI_THREAD();
    const int identifier = browser->GetIdentifier();
    browsers_.erase(
        std::remove_if(browsers_.begin(), browsers_.end(),
                       [identifier](const CefRefPtr<CefBrowser>& candidate) {
                         return candidate->GetIdentifier() == identifier;
                       }),
        browsers_.end());
    if (shutting_down_ && browsers_.empty()) {
      FinalizeShutdown();
    }
  }

  void Shutdown(dispatch_block_t completion) {
    if (![NSThread isMainThread]) {
      dispatch_async(dispatch_get_main_queue(), ^{
        EgakiumCEFRuntime::Shared().Shutdown(completion);
      });
      return;
    }

    if (!initialized_) {
      g_shutdown_complete = true;
      completion();
      return;
    }
    if (shutting_down_) {
      // Application termination owns the single shutdown request. A repeated
      // request does not start a second CEF shutdown sequence.
      return;
    }

    shutting_down_ = true;
    g_shutdown_completion = [completion copy];
    if (browsers_.empty()) {
      FinalizeShutdown();
      return;
    }

    const std::vector<CefRefPtr<CefBrowser>> browsers = browsers_;
    for (const auto& browser : browsers) {
      browser->GetHost()->CloseBrowser(true);
    }
  }

 private:
  class BrowserApp final : public CefApp,
                           public CefBrowserProcessHandler {
   public:
    BrowserApp(client::MainMessageLoopExternalPump* message_pump,
               EgakiumCEFRuntime* runtime)
        : message_pump_(message_pump), runtime_(runtime) {}

    void OnRegisterCustomSchemes(
        CefRawPtr<CefSchemeRegistrar> registrar) override {
      egakium_cef::RegisterCanvasScheme(registrar);
    }

    CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override {
      return this;
    }

    void OnContextInitialized() override {
      runtime_->ContextInitialized();
    }

    void OnScheduleMessagePumpWork(int64_t delay_ms) override {
      message_pump_->OnScheduleMessagePumpWork(delay_ms);
    }

   private:
    client::MainMessageLoopExternalPump* const message_pump_;
    EgakiumCEFRuntime* const runtime_;

    IMPLEMENT_REFCOUNTING(BrowserApp);
  };

  EgakiumCEFRuntime() = default;

  void FinalizeShutdown() {
    CEF_REQUIRE_UI_THREAD();
    context_ready_ = false;
    CefShutdown();
    initialized_ = false;
    g_shutdown_complete = true;
    app_ = nullptr;
    message_pump_.reset();
    library_loader_.reset();
    dispatch_block_t completion = g_shutdown_completion;
    g_shutdown_completion = nil;
    if (completion) {
      completion();
    }
  }

  bool initialized_ = false;
  bool context_ready_ = false;
  bool shutting_down_ = false;
  std::unique_ptr<CefScopedLibraryLoader> library_loader_;
  std::unique_ptr<client::MainMessageLoopExternalPump> message_pump_;
  CefRefPtr<BrowserApp> app_;
  std::vector<CefRefPtr<CefBrowser>> browsers_;
};

class CanvasClient final : public CefClient,
                           public CefLifeSpanHandler,
                           public CefLoadHandler,
                           public CefRequestHandler,
                           public CefResourceRequestHandler {
 public:
  CanvasClient(EgakiumCEFView* owner, std::string canonical_root)
      : owner_(owner),
        scheme_factory_(new CanvasSchemeHandlerFactory(
            std::move(canonical_root))) {}

  bool PrepareRequestContext() {
    CEF_REQUIRE_UI_THREAD();
    CefRequestContextSettings settings;
    request_context_ = CefRequestContext::CreateContext(settings, nullptr);
    return request_context_ && request_context_->RegisterSchemeHandlerFactory(
                                   egakium_cef::kCanvasScheme,
                                   egakium_cef::kCanvasHost,
                                   scheme_factory_);
  }

  CefRefPtr<CefRequestContext> request_context() const {
    return request_context_;
  }

  CefRefPtr<CefBrowser> browser() const { return browser_; }

  void DetachOwner() { owner_ = nil; }

  void Close() {
    close_when_created_ = true;
    if (browser_) {
      browser_->GetHost()->CloseBrowser(true);
    }
  }

  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
  CefRefPtr<CefLoadHandler> GetLoadHandler() override { return this; }
  CefRefPtr<CefRequestHandler> GetRequestHandler() override { return this; }

  void OnAfterCreated(CefRefPtr<CefBrowser> browser) override {
    CEF_REQUIRE_UI_THREAD();
    browser_ = browser;
    EgakiumCEFRuntime::Shared().RegisterBrowser(browser);
    EgakiumCEFView* owner = owner_;
    if (owner) {
      [owner performSelectorOnMainThread:@selector(cefBrowserDidCreate)
                              withObject:nil
                           waitUntilDone:NO];
    }
    if (close_when_created_ || !owner) {
      browser->GetHost()->CloseBrowser(true);
    }
  }

  bool OnBeforePopup(CefRefPtr<CefBrowser> browser,
                     CefRefPtr<CefFrame> frame,
                     int popup_id,
                     const CefString& target_url,
                     const CefString& target_frame_name,
                     WindowOpenDisposition target_disposition,
                     bool user_gesture,
                     const CefPopupFeatures& popup_features,
                     CefWindowInfo& window_info,
                     CefRefPtr<CefClient>& client,
                     CefBrowserSettings& settings,
                     CefRefPtr<CefDictionaryValue>& extra_info,
                     bool* no_javascript_access) override {
    return true;
  }

  bool DoClose(CefRefPtr<CefBrowser> browser) override {
    CEF_REQUIRE_UI_THREAD();
    // This browser is a child of a SwiftUI-owned AppKit view, not a CEF-owned
    // top-level window. Complete CEF's documented non-standard close path by
    // tearing down only the internal child view; closing the product window
    // would also destroy the Cowork harness.
    NSView* browser_view = CAST_CEF_WINDOW_HANDLE_TO_NSVIEW(
        browser->GetHost()->GetWindowHandle());
    [browser_view removeFromSuperview];
    return true;
  }

  void OnBeforeClose(CefRefPtr<CefBrowser> browser) override {
    CEF_REQUIRE_UI_THREAD();
    EgakiumCEFRuntime::Shared().UnregisterBrowser(browser);
    browser_ = nullptr;
    EgakiumCEFView* owner = owner_;
    if (owner) {
      [owner performSelectorOnMainThread:@selector(cefBrowserDidClose)
                              withObject:nil
                           waitUntilDone:NO];
    }
  }

  bool OnBeforeBrowse(CefRefPtr<CefBrowser> browser,
                      CefRefPtr<CefFrame> frame,
                      CefRefPtr<CefRequest> request,
                      bool user_gesture,
                      bool is_redirect) override {
    return !IsAllowedCanvasScheme(SchemeForURL(request->GetURL()));
  }

  bool OnOpenURLFromTab(CefRefPtr<CefBrowser> browser,
                        CefRefPtr<CefFrame> frame,
                        const CefString& target_url,
                        WindowOpenDisposition target_disposition,
                        bool user_gesture) override {
    // A Canvas browser never creates another native or CEF top-level window.
    return true;
  }

  CefRefPtr<CefResourceRequestHandler> GetResourceRequestHandler(
      CefRefPtr<CefBrowser> browser,
      CefRefPtr<CefFrame> frame,
      CefRefPtr<CefRequest> request,
      bool is_navigation,
      bool is_download,
      const CefString& request_initiator,
      bool& disable_default_handling) override {
    disable_default_handling = false;
    return this;
  }

  ReturnValue OnBeforeResourceLoad(CefRefPtr<CefBrowser> browser,
                                   CefRefPtr<CefFrame> frame,
                                   CefRefPtr<CefRequest> request,
                                   CefRefPtr<CefCallback> callback) override {
    return IsAllowedCanvasScheme(SchemeForURL(request->GetURL()))
               ? RV_CONTINUE
               : RV_CANCEL;
  }

  void OnLoadEnd(CefRefPtr<CefBrowser> browser,
                 CefRefPtr<CefFrame> frame,
                 int http_status_code) override {
    if (!frame->IsMain()) {
      return;
    }
    EgakiumCEFView* owner = owner_;
    if (owner) {
      [owner performSelectorOnMainThread:@selector(cefCanvasDidLoad)
                              withObject:nil
                           waitUntilDone:NO];
    }
  }

  void OnLoadError(CefRefPtr<CefBrowser> browser,
                   CefRefPtr<CefFrame> frame,
                   ErrorCode error_code,
                   const CefString& error_text,
                   const CefString& failed_url) override {
    if (!frame->IsMain() || error_code == ERR_ABORTED) {
      return;
    }
    EgakiumCEFView* owner = owner_;
    if (!owner) {
      return;
    }
    NSString* message = [NSString
        stringWithFormat:@"CEF could not load the Session Canvas (%d): %s",
                         static_cast<int>(error_code),
                         error_text.ToString().c_str()];
    [owner performSelectorOnMainThread:@selector(cefCanvasDidFail:)
                            withObject:message
                         waitUntilDone:NO];
  }

 private:
  __weak EgakiumCEFView* owner_;
  bool close_when_created_ = false;
  CefRefPtr<CanvasSchemeHandlerFactory> scheme_factory_;
  CefRefPtr<CefRequestContext> request_context_;
  CefRefPtr<CefBrowser> browser_;

  IMPLEMENT_REFCOUNTING(CanvasClient);
};

bool EgakiumCEFRuntime::Initialize(std::string* failure) {
  if (initialized_) {
    return true;
  }
  if (shutting_down_) {
    *failure = "CEF shutdown has already started.";
    return false;
  }

  library_loader_ = std::make_unique<CefScopedLibraryLoader>();
  if (!library_loader_->LoadInMain()) {
    library_loader_.reset();
    *failure = "The official Chromium Embedded Framework could not be loaded from the App bundle.";
    return false;
  }

  message_pump_ = client::MainMessageLoopExternalPump::Create();
  if (!message_pump_) {
    library_loader_.reset();
    *failure = "CEF could not create its official external message pump.";
    return false;
  }

  app_ = new BrowserApp(message_pump_.get(), this);
  CefSettings settings;
  settings.external_message_pump = true;
  settings.multi_threaded_message_loop = false;
  settings.no_sandbox = false;
  settings.persist_session_cookies = false;
  settings.log_severity = LOGSEVERITY_WARNING;
  settings.background_color = CefColorSetARGB(255, 247, 247, 245);
  std::string root_cache_path;
  if (!ResolveCEFRootCachePath(&root_cache_path, failure)) {
    app_ = nullptr;
    message_pump_.reset();
    library_loader_.reset();
    return false;
  }
  CefString(&settings.root_cache_path).FromString(root_cache_path);

  CefMainArgs main_args(*_NSGetArgc(), *_NSGetArgv());
  if (!CefInitialize(main_args, settings, app_.get(), nullptr)) {
    const int exit_code = CefGetExitCode();
    app_ = nullptr;
    message_pump_.reset();
    library_loader_.reset();
    *failure = "CefInitialize failed with exit code " +
               std::to_string(exit_code) + ".";
    return false;
  }

  initialized_ = true;
  g_shutdown_complete = false;
  return true;
}

}  // namespace

// SwiftUI instantiates its own private NSApplication subclass and ignores
// NSPrincipalClass. CEF's official JCEF integration uses this category and
// swizzling pattern when a host framework owns NSApplication. We keep only the
// CEF-required event-state and orderly-termination pieces.
@interface NSApplication (EgakiumCEFApplication) <CefAppProtocol>
- (BOOL)isHandlingSendEvent;
- (void)setHandlingSendEvent:(BOOL)handlingSendEvent;
- (void)_egakium_cef_sendEvent:(NSEvent*)event;
- (void)_egakium_cef_terminate:(id)sender;
- (void)_egakium_cef_completeOrderlyTermination;
@end

@implementation NSApplication (EgakiumCEFApplication)

+ (void)load {
  Method original_send_event =
      class_getInstanceMethod(self, @selector(sendEvent:));
  Method cef_send_event =
      class_getInstanceMethod(self, @selector(_egakium_cef_sendEvent:));
  method_exchangeImplementations(original_send_event, cef_send_event);

  Method original_terminate =
      class_getInstanceMethod(self, @selector(terminate:));
  Method cef_terminate =
      class_getInstanceMethod(self, @selector(_egakium_cef_terminate:));
  method_exchangeImplementations(original_terminate, cef_terminate);
}

- (BOOL)isHandlingSendEvent {
  return g_handling_send_event;
}

- (void)setHandlingSendEvent:(BOOL)handlingSendEvent {
  g_handling_send_event = handlingSendEvent;
}

- (void)_egakium_cef_sendEvent:(NSEvent*)event {
  CefScopedSendingEvent sending_event;
  // Calls the original NSApplication implementation after swizzling.
  [self _egakium_cef_sendEvent:event];
}

- (void)_egakium_cef_terminate:(id)sender {
  if (g_orderly_termination_pending) {
    return;
  }
  id<NSApplicationDelegate> delegate = self.delegate;
  if (![delegate respondsToSelector:@selector(applicationShouldTerminate:)]) {
    [self _egakium_cef_terminate:sender];
    return;
  }
  const NSApplicationTerminateReply reply =
      [delegate applicationShouldTerminate:self];
  switch (reply) {
    case NSTerminateNow:
      [self _egakium_cef_completeOrderlyTermination];
      break;
    case NSTerminateCancel:
      break;
    case NSTerminateLater:
      g_orderly_termination_pending = true;
      break;
  }
}

- (void)_egakium_cef_completeOrderlyTermination {
  g_orderly_termination_pending = false;
  // Calls the original NSApplication implementation after swizzling. The
  // delegate now returns NSTerminateNow because CEF shutdown is complete.
  [self _egakium_cef_terminate:nil];
}

@end

BOOL EgakiumCEFInitialize(void) {
  if (![NSThread isMainThread]) {
    g_initialization_error =
        @"CEF must be initialized on the browser-process main thread.";
    return NO;
  }
  NSApplication* application = NSApplication.sharedApplication;
  if (![application conformsToProtocol:@protocol(CefAppProtocol)] ||
      ![application respondsToSelector:@selector(isHandlingSendEvent)] ||
      ![application respondsToSelector:@selector(setHandlingSendEvent:)]) {
    g_initialization_error =
        @"The SwiftUI NSApplication could not install CEF's required macOS event protocol.";
    return NO;
  }

  std::string failure;
  if (!EgakiumCEFRuntime::Shared().Initialize(&failure)) {
    NSString* message = [NSString stringWithUTF8String:failure.c_str()];
    g_initialization_error = message;
    return NO;
  }
  g_initialization_error = nil;
  return YES;
}

BOOL EgakiumCEFIsAvailable(void) {
  return EgakiumCEFRuntime::Shared().IsAvailable();
}

NSString* EgakiumCEFInitializationError(void) {
  return g_initialization_error;
}

void EgakiumCEFShutdown(dispatch_block_t completion) {
  EgakiumCEFRuntime::Shared().Shutdown(completion);
}

BOOL EgakiumCEFShutdownIsComplete(void) {
  return g_shutdown_complete;
}

void EgakiumCEFCompleteApplicationTermination(void) {
  if (![NSThread isMainThread]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      EgakiumCEFCompleteApplicationTermination();
    });
    return;
  }
  [NSApplication.sharedApplication _egakium_cef_completeOrderlyTermination];
}

@interface EgakiumCEFView ()
- (void)ensureCEFBrowser;
- (void)showCEFStatus:(NSString*)message;
- (void)cefBrowserDidCreate;
- (void)cefBrowserDidClose;
- (void)cefCanvasDidLoad;
- (void)cefCanvasDidFail:(NSString*)message;
@end

@implementation EgakiumCEFView

- (instancetype)initWithFrame:(NSRect)frameRect {
  self = [super initWithFrame:frameRect];
  if (self) {
    self.wantsLayer = YES;
    _cefStatusLabel = [NSTextField labelWithString:@"Starting CEF…"];
    _cefStatusLabel.alignment = NSTextAlignmentCenter;
    _cefStatusLabel.textColor = NSColor.secondaryLabelColor;
    _cefStatusLabel.maximumNumberOfLines = 0;
    _cefStatusLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self addSubview:_cefStatusLabel];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(cefContextReady:)
               name:kEgakiumCEFContextReadyNotification
             object:nil];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder*)coder {
  self = [super initWithCoder:coder];
  if (self) {
    _cefStatusLabel = [NSTextField labelWithString:@"Starting CEF…"];
    _cefStatusLabel.alignment = NSTextAlignmentCenter;
    _cefStatusLabel.textColor = NSColor.secondaryLabelColor;
    _cefStatusLabel.maximumNumberOfLines = 0;
    _cefStatusLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self addSubview:_cefStatusLabel];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(cefContextReady:)
               name:kEgakiumCEFContextReadyNotification
             object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  if (_cefClientStorage) {
    auto* storage =
        static_cast<CefRefPtr<CanvasClient>*>(_cefClientStorage);
    (*storage)->DetachOwner();
    (*storage)->Close();
    delete storage;
    _cefClientStorage = nullptr;
  }
}

- (BOOL)isFlipped {
  return YES;
}

- (void)viewDidMoveToWindow {
  [super viewDidMoveToWindow];
  [self ensureCEFBrowser];
}

- (void)layout {
  [super layout];
  const CGFloat label_width = std::max<CGFloat>(0, self.bounds.size.width - 48);
  _cefStatusLabel.frame = NSMakeRect(
      24, std::max<CGFloat>(24, (self.bounds.size.height - 80) / 2),
      label_width, 80);

  if (!_cefClientStorage) {
    return;
  }
  auto* storage = static_cast<CefRefPtr<CanvasClient>*>(_cefClientStorage);
  CefRefPtr<CefBrowser> browser = (*storage)->browser();
  if (!browser) {
    return;
  }
  NSView* browser_view =
      CAST_CEF_WINDOW_HANDLE_TO_NSVIEW(browser->GetHost()->GetWindowHandle());
  browser_view.frame = self.bounds;
  browser_view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
}

- (BOOL)loadCanvasIndexURL:(NSURL*)indexURL
            readAccessURL:(NSURL*)readAccessURL {
  if (_cefClosed) {
    [self showCEFStatus:@"The CEF Canvas view is already closed."];
    return NO;
  }
  if (!EgakiumCEFIsAvailable()) {
    NSString* message = EgakiumCEFInitializationError() ?:
        @"The official Chromium Embedded Framework is unavailable.";
    [self showCEFStatus:message];
    return NO;
  }
  if (!indexURL.isFileURL || !readAccessURL.isFileURL) {
    [self showCEFStatus:@"Session Canvas URLs must be local files."];
    return NO;
  }

  std::string canonical_root;
  std::string relative_index;
  std::string failure;
  if (!ValidateCanvasRootAndIndex(readAccessURL.fileSystemRepresentation,
                                  indexURL.fileSystemRepresentation,
                                  &canonical_root, &relative_index, &failure)) {
    NSString* message = [NSString stringWithUTF8String:failure.c_str()];
    [self showCEFStatus:message];
    return NO;
  }

  NSString* canonical_root_string =
      [NSString stringWithUTF8String:canonical_root.c_str()];
  if (_cefRootPath && ![_cefRootPath isEqualToString:canonical_root_string]) {
    [self showCEFStatus:
        @"A CEF Canvas view cannot be rebound to another Session root."];
    return NO;
  }
  _cefRootPath = canonical_root_string;

  NSString* relative = [NSString stringWithUTF8String:relative_index.c_str()];
  NSString* encoded = [relative
      stringByAddingPercentEncodingWithAllowedCharacters:
          NSCharacterSet.URLPathAllowedCharacterSet];
  if (!encoded) {
    [self showCEFStatus:
        @"The Session Canvas index path is not a valid URL path."];
    return NO;
  }
  _cefIndexURL = [NSString stringWithFormat:@"egakium://canvas/%@", encoded];

  if (!_cefClientStorage) {
    CefRefPtr<CanvasClient> client(
        new CanvasClient(self, std::move(canonical_root)));
    _cefClientStorage = new CefRefPtr<CanvasClient>(client);
  }
  [self ensureCEFBrowser];
  return YES;
}

- (void)reloadCanvas {
  if (!_cefClientStorage) {
    return;
  }
  auto* storage = static_cast<CefRefPtr<CanvasClient>*>(_cefClientStorage);
  CefRefPtr<CefBrowser> browser = (*storage)->browser();
  if (browser) {
    browser->ReloadIgnoreCache();
  }
}

- (void)closeBrowser {
  if (_cefClosed) {
    return;
  }
  _cefClosed = YES;
  if (_cefClientStorage) {
    auto* storage = static_cast<CefRefPtr<CanvasClient>*>(_cefClientStorage);
    (*storage)->DetachOwner();
    (*storage)->Close();
  }
}

- (void)cefContextReady:(NSNotification*)notification {
  [self ensureCEFBrowser];
}

- (void)ensureCEFBrowser {
  if (_cefClosed || _cefCreationRequested || !_cefClientStorage ||
      !_cefIndexURL || !self.window ||
      !EgakiumCEFRuntime::Shared().IsContextReady()) {
    return;
  }

  auto* storage = static_cast<CefRefPtr<CanvasClient>*>(_cefClientStorage);
  if (!(*storage)->PrepareRequestContext()) {
    [self showCEFStatus:@"CEF could not create an isolated Session request context."];
    return;
  }

  CefWindowInfo window_info;
  window_info.SetAsChild(CAST_NSVIEW_TO_CEF_WINDOW_HANDLE(self),
                         CefRect(0, 0, std::max(1, static_cast<int>(self.bounds.size.width)),
                                 std::max(1, static_cast<int>(self.bounds.size.height))));
  window_info.runtime_style = CEF_RUNTIME_STYLE_ALLOY;

  CefBrowserSettings browser_settings;
  browser_settings.background_color = CefColorSetARGB(255, 247, 247, 245);
  _cefCreationRequested = CefBrowserHost::CreateBrowser(
      window_info, *storage, _cefIndexURL.UTF8String, browser_settings,
      nullptr, (*storage)->request_context());
  if (!_cefCreationRequested) {
    [self showCEFStatus:@"CEF rejected creation of the Session Canvas browser."];
  }
}

- (void)showCEFStatus:(NSString*)message {
  _cefStatusLabel.stringValue = message;
  _cefStatusLabel.hidden = NO;
  [self addSubview:_cefStatusLabel positioned:NSWindowAbove relativeTo:nil];
  [self setNeedsLayout:YES];
}

- (void)cefBrowserDidCreate {
  if (!_cefClientStorage) {
    return;
  }
  auto* storage = static_cast<CefRefPtr<CanvasClient>*>(_cefClientStorage);
  CefRefPtr<CefBrowser> browser = (*storage)->browser();
  if (!browser) {
    return;
  }
  NSView* browser_view =
      CAST_CEF_WINDOW_HANDLE_TO_NSVIEW(browser->GetHost()->GetWindowHandle());
  browser_view.frame = self.bounds;
  browser_view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [self layoutSubtreeIfNeeded];
}

- (void)cefBrowserDidClose {
  _cefCreationRequested = NO;
}

- (void)cefCanvasDidLoad {
  _cefStatusLabel.hidden = YES;
}

- (void)cefCanvasDidFail:(NSString*)message {
  [self showCEFStatus:message];
}

@end
