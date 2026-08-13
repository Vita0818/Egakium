#!/bin/zsh

set -euo pipefail

egakium_script=${0:A}
egakium_project_root=${egakium_script:h:h}
egakium_chromium="$egakium_project_root/Chromium/checkout/src/out/EgakiumNative/Chromium.app/Contents/MacOS/Chromium"
egakium_bundle="$egakium_project_root/out/Egakium.app"
egakium_contents="$egakium_bundle/Contents"

if [[ ! -x "$egakium_chromium" ]]; then
  print -u2 -- "Egakium: build Chromium first; executable not found: $egakium_chromium"
  exit 1
fi

/bin/mkdir -p "$egakium_contents/MacOS" "$egakium_contents/Resources/canvas"
/usr/bin/install -m 0755 \
  "$egakium_project_root/packaging/macos/Egakium" \
  "$egakium_contents/MacOS/Egakium"
/usr/bin/install -m 0644 \
  "$egakium_project_root/packaging/macos/Info.plist" \
  "$egakium_contents/Info.plist"
/usr/bin/install -m 0644 \
  "$egakium_project_root/src/canvas/index.html" \
  "$egakium_contents/Resources/canvas/index.html"

/usr/bin/plutil -lint "$egakium_contents/Info.plist"
print -r -- "$egakium_bundle"
