# Official CEF macOS ARM64 Standard Distribution pinned for Egakium.
#
# This is the only Canvas renderer dependency accepted by the product. Build
# scripts must fail when these exact assets are unavailable or fail integrity
# checks; they must not select a different renderer.
set(EGAKIUM_CEF_VERSION "151.3.17+gf059e67+chromium-151.0.7922.138")
set(EGAKIUM_CEF_PLATFORM "macosarm64")
set(EGAKIUM_CEF_ARCHIVE
    "cef_binary_${EGAKIUM_CEF_VERSION}_${EGAKIUM_CEF_PLATFORM}.tar.bz2")
set(EGAKIUM_CEF_URL
    "https://cef-builds.spotifycdn.com/${EGAKIUM_CEF_ARCHIVE}")
set(EGAKIUM_CEF_SHA1 "da0d745ac91cabc252eaa53c3c60c2aa60c73991")
set(EGAKIUM_CEF_SHA256
    "b5302117aadb2255650cb721840d2512f0cb5e321b5ca446b1b07005afb948d2")
