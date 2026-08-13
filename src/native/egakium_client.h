#ifndef EGAKIUM_SRC_NATIVE_EGAKIUM_CLIENT_H_
#define EGAKIUM_SRC_NATIVE_EGAKIUM_CLIENT_H_

#include <list>

#include "include/cef_client.h"
#include "include/cef_context_menu_handler.h"
#include "include/cef_display_handler.h"
#include "include/cef_life_span_handler.h"

class EgakiumClient final : public CefClient,
                            public CefContextMenuHandler,
                            public CefDisplayHandler,
                            public CefLifeSpanHandler {
 public:
  EgakiumClient();

  static EgakiumClient* GetInstance();

  CefRefPtr<CefContextMenuHandler> GetContextMenuHandler() override {
    return this;
  }
  CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }

  void OnBeforeContextMenu(CefRefPtr<CefBrowser> browser,
                           CefRefPtr<CefFrame> frame,
                           CefRefPtr<CefContextMenuParams> params,
                           CefRefPtr<CefMenuModel> model) override;
  void OnTitleChange(CefRefPtr<CefBrowser> browser,
                     const CefString& title) override;
  void OnAfterCreated(CefRefPtr<CefBrowser> browser) override;
  bool DoClose(CefRefPtr<CefBrowser> browser) override;
  void OnBeforeClose(CefRefPtr<CefBrowser> browser) override;

  void ShowMainWindow();
  void CloseAllBrowsers(bool force_close);
  bool IsClosing() const { return is_closing_; }

 private:
  ~EgakiumClient() override;

  using BrowserList = std::list<CefRefPtr<CefBrowser>>;
  BrowserList browser_list_;
  bool is_closing_ = false;

  EgakiumClient(const EgakiumClient&) = delete;
  EgakiumClient& operator=(const EgakiumClient&) = delete;

  IMPLEMENT_REFCOUNTING(EgakiumClient);
};

#endif  // EGAKIUM_SRC_NATIVE_EGAKIUM_CLIENT_H_
