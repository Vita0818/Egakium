#import <Cocoa/Cocoa.h>

#include "include/cef_application_mac.h"
#include "include/wrapper/cef_helpers.h"
#include "include/wrapper/cef_library_loader.h"
#include "src/native/egakium_app.h"
#include "src/native/egakium_client.h"

namespace {

void ConfigureUserDataPaths(CefSettings& settings) {
  NSArray<NSString*>* application_support_paths =
      NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                          NSUserDomainMask, YES);
  NSString* application_support_path = application_support_paths.firstObject;
  if (!application_support_path) {
    return;
  }

  NSString* root_cache_path =
      [application_support_path stringByAppendingPathComponent:@"Egakium/CEF"];
  NSString* cache_path =
      [root_cache_path stringByAppendingPathComponent:@"Default"];

  [[NSFileManager defaultManager] createDirectoryAtPath:cache_path
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];

  CefString(&settings.root_cache_path).FromString(root_cache_path.UTF8String);
  CefString(&settings.cache_path).FromString(cache_path.UTF8String);
}

}  // namespace

@interface EgakiumAppDelegate : NSObject <NSApplicationDelegate>
- (void)createApplication:(id)object;
- (void)tryToTerminateApplication:(NSApplication*)application;
@end

@interface EgakiumApplication : NSApplication <CefAppProtocol> {
 @private
  BOOL handlingSendEvent_;
}
@end

@implementation EgakiumApplication

- (BOOL)isHandlingSendEvent {
  return handlingSendEvent_;
}

- (void)setHandlingSendEvent:(BOOL)handlingSendEvent {
  handlingSendEvent_ = handlingSendEvent;
}

- (void)sendEvent:(NSEvent*)event {
  CefScopedSendingEvent sending_event;
  [super sendEvent:event];
}

- (void)terminate:(id)sender {
  EgakiumAppDelegate* delegate =
      static_cast<EgakiumAppDelegate*>(NSApp.delegate);
  [delegate tryToTerminateApplication:self];
}

@end

@implementation EgakiumAppDelegate

- (void)createApplication:(id)object {
  [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

  NSMenu* main_menu = [[NSMenu alloc] initWithTitle:@"Egakium"];
  NSMenuItem* app_menu_item = [[NSMenuItem alloc] init];
  [main_menu addItem:app_menu_item];

  NSMenu* app_menu = [[NSMenu alloc] initWithTitle:@"Egakium"];
  NSMenuItem* quit_item =
      [[NSMenuItem alloc] initWithTitle:@"Quit Egakium"
                                action:@selector(terminate:)
                         keyEquivalent:@"q"];
  [app_menu addItem:quit_item];
  [app_menu_item setSubmenu:app_menu];
  [NSApp setMainMenu:main_menu];
  [NSApp setDelegate:self];
}

- (void)tryToTerminateApplication:(NSApplication*)application {
  EgakiumClient* client = EgakiumClient::GetInstance();
  if (client && !client->IsClosing()) {
    client->CloseAllBrowsers(false);
  }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:
    (NSApplication*)sender {
  return NSTerminateNow;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication*)application
                    hasVisibleWindows:(BOOL)hasVisibleWindows {
  EgakiumClient* client = EgakiumClient::GetInstance();
  if (client && !client->IsClosing()) {
    client->ShowMainWindow();
  }
  return NO;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication*)application {
  return YES;
}

@end

int main(int argc, char* argv[]) {
  CefScopedLibraryLoader library_loader;
  if (!library_loader.LoadInMain()) {
    return 1;
  }

  CefMainArgs main_args(argc, argv);

  @autoreleasepool {
    [EgakiumApplication sharedApplication];
    if (![NSApp isKindOfClass:[EgakiumApplication class]]) {
      return 2;
    }

    CefSettings settings;
    settings.no_sandbox = true;
    settings.background_color = CefColorSetARGB(255, 255, 255, 255);
    settings.log_severity = LOGSEVERITY_WARNING;
    ConfigureUserDataPaths(settings);

    CefRefPtr<EgakiumApp> app(new EgakiumApp);
    if (!CefInitialize(main_args, settings, app.get(), nullptr)) {
      return CefGetExitCode();
    }

    EgakiumAppDelegate* delegate = [[EgakiumAppDelegate alloc] init];
    NSApp.delegate = delegate;
    [delegate performSelectorOnMainThread:@selector(createApplication:)
                               withObject:nil
                            waitUntilDone:NO];

    CefRunMessageLoop();
    CefShutdown();

    NSApp.delegate = nil;
    delegate = nil;
  }

  return 0;
}
