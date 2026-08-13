#import <Cocoa/Cocoa.h>

#include <string>

#include "src/native/egakium_app.h"

#include "include/cef_browser.h"
#include "include/cef_command_line.h"
#include "include/views/cef_browser_view.h"
#include "include/views/cef_window.h"
#include "include/wrapper/cef_helpers.h"
#include "src/native/egakium_client.h"

namespace {

std::string GetCanvasUrl() {
  @autoreleasepool {
    NSURL* canvas_url = [[NSBundle mainBundle] URLForResource:@"index"
                                                withExtension:@"html"
                                                 subdirectory:@"canvas"];
    if (canvas_url) {
      return canvas_url.absoluteString.UTF8String;
    }
  }

  // Keep startup deterministic even if packaging is temporarily incomplete.
  // Bundle validation separately verifies that the real canvas file exists.
  return "data:text/html;charset=utf-8,%3Ctitle%3EEgakium%3C%2Ftitle%3E"
         "%3Cbody%20style%3D%22margin%3A0%3Bbackground%3Awhite%22%3E"
         "%3C%2Fbody%3E";
}

class EgakiumWindowDelegate final : public CefWindowDelegate {
 public:
  explicit EgakiumWindowDelegate(CefRefPtr<CefBrowserView> browser_view)
      : browser_view_(browser_view) {}

  void OnWindowCreated(CefRefPtr<CefWindow> window) override {
    window->AddChildView(browser_view_);
    window->SetTitle("Egakium");
    window->Show();
    window->Activate();
  }

  void OnWindowDestroyed(CefRefPtr<CefWindow> window) override {
    browser_view_ = nullptr;
  }

  bool CanClose(CefRefPtr<CefWindow> window) override {
    CefRefPtr<CefBrowser> browser = browser_view_->GetBrowser();
    return !browser || browser->GetHost()->TryCloseBrowser();
  }

  CefSize GetPreferredSize(CefRefPtr<CefView> view) override {
    return CefSize(1280, 800);
  }

  cef_runtime_style_t GetWindowRuntimeStyle() override {
    return CEF_RUNTIME_STYLE_ALLOY;
  }

 private:
  CefRefPtr<CefBrowserView> browser_view_;

  EgakiumWindowDelegate(const EgakiumWindowDelegate&) = delete;
  EgakiumWindowDelegate& operator=(const EgakiumWindowDelegate&) = delete;

  IMPLEMENT_REFCOUNTING(EgakiumWindowDelegate);
};

class EgakiumBrowserViewDelegate final : public CefBrowserViewDelegate {
 public:
  cef_runtime_style_t GetBrowserRuntimeStyle() override {
    return CEF_RUNTIME_STYLE_ALLOY;
  }

 private:
  IMPLEMENT_REFCOUNTING(EgakiumBrowserViewDelegate);
};

}  // namespace

void EgakiumApp::OnBeforeCommandLineProcessing(
    const CefString& process_type,
    CefRefPtr<CefCommandLine> command_line) {
  if (process_type.empty()) {
    command_line->AppendSwitch("disable-background-networking");
    command_line->AppendSwitch("disable-component-update");
    command_line->AppendSwitch("no-first-run");
  }
}

void EgakiumApp::OnContextInitialized() {
  CEF_REQUIRE_UI_THREAD();

  CefRefPtr<EgakiumClient> client(new EgakiumClient);

  CefBrowserSettings browser_settings;
  browser_settings.background_color = CefColorSetARGB(255, 255, 255, 255);

  CefRefPtr<CefBrowserView> browser_view = CefBrowserView::CreateBrowserView(
      client, GetCanvasUrl(), browser_settings, nullptr, nullptr,
      new EgakiumBrowserViewDelegate);

  CefWindow::CreateTopLevelWindow(new EgakiumWindowDelegate(browser_view));
}
