# Chromium Embedded Framework

Egakium's macOS Session Canvas directly uses the official Chromium Embedded
Framework (CEF) Standard Distribution. CEF is the sole Canvas renderer; the
product has no WebKit Canvas backend, compatibility renderer, or runtime
fallback.

## Pinned upstream identity

- Component: Chromium Embedded Framework macOS ARM64 Standard Distribution
- CEF version: `151.3.17+gf059e67+chromium-151.0.7922.138`
- Platform archive: `macosarm64`
- Archive:
  `cef_binary_151.3.17+gf059e67+chromium-151.0.7922.138_macosarm64.tar.bz2`
- Upstream URL:
  `https://cef-builds.spotifycdn.com/cef_binary_151.3.17+gf059e67+chromium-151.0.7922.138_macosarm64.tar.bz2`
- Archive SHA-256:
  `b5302117aadb2255650cb721840d2512f0cb5e321b5ca446b1b07005afb948d2`
- Archive SHA-1: `da0d745ac91cabc252eaa53c3c60c2aa60c73991`
- CEF source commit: `f059e67fa6aad5e8cce8bebea5df706ffddfb174`
- Chromium source commit: `41fa82442390a4d4456c78f2d69a832d5720cb27`

The canonical machine-readable build pin is `config/cef.cmake`. The downloaded
archive and extracted distribution are local build assets under `.deps/` and
are intentionally not copied into Git.

## Reuse and runtime scope

The build compiles CEF's unmodified `libcef_dll_wrapper` and official external
message-pump source from the pinned distribution. It embeds the official
`Chromium Embedded Framework.framework`, resources, and the five standard
macOS Helper app variants. Helper processes initialize CEF's supplied macOS
sandbox before dynamically loading the framework.

SwiftUI creates a private `NSApplication` subclass instead of honoring a CEF
principal class. The required `CefAppProtocol` event-state and orderly-quit
wiring therefore derives the narrow NSApplication category/swizzling pattern
from official JCEF `native/util_mac.mm`, repository
`chromiumembedded/java-cef` commit
`6d3e8ca02cd3ec0af163086f9a79281beb0cc60e`. JCEF's unrelated Java/AWT mouse
monitoring, browser registry, JNI and application wrapper are not copied.

Project-owned Objective-C++ is limited to the required host wiring:

- `NSApplication`/CEF event-loop lifecycle;
- an official CEF child browser attached to the existing AppKit view;
- one isolated, memory-only request context per Canvas view;
- an `egakium://canvas` scheme rooted at the exact Session Canvas directory;
- denial of popups and non-local network schemes;
- orderly browser close and `CefShutdown` during application termination;
- bundle, Helper, Hardened Runtime, signing, and versioned-framework wiring.

It does not implement an HTML engine, Chromium substitute, browser adapter
interface, parallel backend, or CEF failure fallback.

## License and distributed notices

CEF is distributed under its BSD-style license, reproduced at
`ThirdPartyNotices/Licenses/CEF-151.3.17-LICENSE.txt`. Chromium and other code
included by the official binary distribution have additional attributions in
the upstream `CREDITS.html`.

The JCEF-derived lifecycle pattern uses JCEF's BSD-style license, reproduced at
`ThirdPartyNotices/Licenses/JCEF-6d3e8ca0-LICENSE.txt`.

Every built Egakium App copies the exact distribution's `LICENSE.txt` and
`CREDITS.html` to `Contents/Resources/ThirdPartyNotices/CEF/`. Release
validation fails if either file, the CEF framework, or any required Helper is
missing.
