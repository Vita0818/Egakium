// Copyright (c) 2013 The Chromium Embedded Framework Authors.
// Use of this source code is governed by the BSD-style CEF license bundled
// with the official binary distribution.

#include "include/cef_app.h"
#include "include/cef_sandbox_mac.h"
#include "include/wrapper/cef_library_loader.h"
#include "EgakiumCEFScheme.h"

namespace {

class EgakiumCEFSubprocessApp final : public CefApp {
 public:
  void OnRegisterCustomSchemes(
      CefRawPtr<CefSchemeRegistrar> registrar) override {
    egakium_cef::RegisterCanvasScheme(registrar);
  }

 private:
  IMPLEMENT_REFCOUNTING(EgakiumCEFSubprocessApp);
};

}  // namespace

int main(int argc, char* argv[]) {
  // This is the official CEF macOS helper sequence: sandbox first, then load
  // the framework from the containing App bundle, then execute the subprocess.
  CefScopedSandboxContext sandbox_context;
  if (!sandbox_context.Initialize(argc, argv)) {
    return 1;
  }

  CefScopedLibraryLoader library_loader;
  if (!library_loader.LoadInHelper()) {
    return 1;
  }

  CefMainArgs main_args(argc, argv);
  CefRefPtr<EgakiumCEFSubprocessApp> app(new EgakiumCEFSubprocessApp);
  return CefExecuteProcess(main_args, app.get(), nullptr);
}
