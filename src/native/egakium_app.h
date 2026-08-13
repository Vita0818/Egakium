#ifndef EGAKIUM_SRC_NATIVE_EGAKIUM_APP_H_
#define EGAKIUM_SRC_NATIVE_EGAKIUM_APP_H_

#include "include/cef_app.h"

class EgakiumApp final : public CefApp, public CefBrowserProcessHandler {
 public:
  EgakiumApp() = default;

  CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override {
    return this;
  }

  void OnBeforeCommandLineProcessing(
      const CefString& process_type,
      CefRefPtr<CefCommandLine> command_line) override;

  void OnContextInitialized() override;

 private:
  EgakiumApp(const EgakiumApp&) = delete;
  EgakiumApp& operator=(const EgakiumApp&) = delete;

  IMPLEMENT_REFCOUNTING(EgakiumApp);
};

#endif  // EGAKIUM_SRC_NATIVE_EGAKIUM_APP_H_
