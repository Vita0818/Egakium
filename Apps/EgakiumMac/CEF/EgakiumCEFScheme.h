#ifndef EGAKIUM_CEF_SCHEME_H_
#define EGAKIUM_CEF_SCHEME_H_

#include "include/cef_scheme.h"

namespace egakium_cef {

inline constexpr char kCanvasScheme[] = "egakium";
inline constexpr char kCanvasHost[] = "canvas";

inline bool RegisterCanvasScheme(CefRawPtr<CefSchemeRegistrar> registrar) {
  return registrar->AddCustomScheme(
      kCanvasScheme,
      CEF_SCHEME_OPTION_STANDARD | CEF_SCHEME_OPTION_SECURE |
          CEF_SCHEME_OPTION_DISPLAY_ISOLATED);
}

}  // namespace egakium_cef

#endif  // EGAKIUM_CEF_SCHEME_H_
