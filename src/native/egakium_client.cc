#include "src/native/egakium_client.h"

#include "include/cef_app.h"
#include "include/views/cef_browser_view.h"
#include "include/views/cef_window.h"
#include "include/wrapper/cef_helpers.h"

namespace {

EgakiumClient* g_instance = nullptr;

}  // namespace

EgakiumClient::EgakiumClient() {
  DCHECK(!g_instance);
  g_instance = this;
}

EgakiumClient::~EgakiumClient() {
  g_instance = nullptr;
}

// static
EgakiumClient* EgakiumClient::GetInstance() {
  return g_instance;
}

void EgakiumClient::OnBeforeContextMenu(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    CefRefPtr<CefContextMenuParams> params,
    CefRefPtr<CefMenuModel> model) {
  CEF_REQUIRE_UI_THREAD();
  model->Clear();
}

void EgakiumClient::OnTitleChange(CefRefPtr<CefBrowser> browser,
                                  const CefString& title) {
  CEF_REQUIRE_UI_THREAD();

  if (auto browser_view = CefBrowserView::GetForBrowser(browser)) {
    if (auto window = browser_view->GetWindow()) {
      window->SetTitle(title.empty() ? CefString("Egakium") : title);
    }
  }
}

void EgakiumClient::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  browser_list_.push_back(browser);
}

bool EgakiumClient::DoClose(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();

  if (browser_list_.size() == 1) {
    is_closing_ = true;
  }

  return false;
}

void EgakiumClient::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();

  for (auto iterator = browser_list_.begin(); iterator != browser_list_.end();
       ++iterator) {
    if ((*iterator)->IsSame(browser)) {
      browser_list_.erase(iterator);
      break;
    }
  }

  if (browser_list_.empty()) {
    CefQuitMessageLoop();
  }
}

void EgakiumClient::ShowMainWindow() {
  CEF_REQUIRE_UI_THREAD();

  if (browser_list_.empty()) {
    return;
  }

  if (auto browser_view = CefBrowserView::GetForBrowser(browser_list_.front())) {
    if (auto window = browser_view->GetWindow()) {
      window->Show();
      window->Activate();
    }
  }
}

void EgakiumClient::CloseAllBrowsers(bool force_close) {
  CEF_REQUIRE_UI_THREAD();

  for (const auto& browser : browser_list_) {
    browser->GetHost()->CloseBrowser(force_close);
  }
}
