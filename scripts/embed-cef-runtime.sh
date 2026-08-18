#!/bin/zsh

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
project_root="$(cd "$script_dir/.." && pwd -P)"
app_path="${1:-}"
configuration="${2:-${CONFIGURATION:-Debug}}"

[[ -n "$app_path" && -d "$app_path/Contents" ]] || {
    print -u2 -- "error: an existing macOS App bundle is required for CEF embedding"
    exit 1
}
case "$configuration" in
    Debug|Release)
        ;;
    *)
        print -u2 -- "error: unsupported CEF configuration: $configuration"
        exit 1
        ;;
esac

cef_config="$project_root/config/cef.cmake"
cef_version="$(/usr/bin/awk -F'"' \
    '/^set\(EGAKIUM_CEF_VERSION / { print $2; exit }' "$cef_config")"
cef_platform="$(/usr/bin/awk -F'"' \
    '/^set\(EGAKIUM_CEF_PLATFORM / { print $2; exit }' "$cef_config")"
cef_root="$project_root/.deps/cef/cef_binary_${cef_version}_${cef_platform}"
source_framework="$cef_root/$configuration/Chromium Embedded Framework.framework"
helper_root="$project_root/build/egakium-cef-runtime/$configuration"
frameworks_dir="$app_path/Contents/Frameworks"
framework_dest="$frameworks_dir/Chromium Embedded Framework.framework"
notice_dest="$app_path/Contents/Resources/ThirdPartyNotices/CEF"

[[ -d "$source_framework" && -d "$helper_root" ]] || {
    print -u2 -- "error: prepared official CEF products are unavailable"
    exit 1
}

/bin/mkdir -p "$frameworks_dir"
if [[ -e "$framework_dest" || -L "$framework_dest" ]]; then
    /bin/rm -rf -- "$framework_dest"
fi
/bin/mkdir -p "$framework_dest/Versions"
/usr/bin/ditto "$source_framework" "$framework_dest/Versions/A"
(
    cd "$framework_dest"
    /bin/ln -s "Versions/A/Chromium Embedded Framework" \
        "Chromium Embedded Framework"
    /bin/ln -s "Versions/A/Libraries" "Libraries"
    /bin/ln -s "Versions/A/Resources" "Resources"
    cd "$framework_dest/Versions"
    /bin/ln -s "A" "Current"
)

typeset -a helpers
helpers=(
    "EgakiumMac Helper"
    "EgakiumMac Helper (Alerts)"
    "EgakiumMac Helper (GPU)"
    "EgakiumMac Helper (Plugin)"
    "EgakiumMac Helper (Renderer)"
)
for helper in "${helpers[@]}"; do
    source_helper="$helper_root/$helper.app"
    destination_helper="$frameworks_dir/$helper.app"
    [[ -x "$source_helper/Contents/MacOS/$helper" ]] || {
        print -u2 -- "error: CEF Helper executable is missing: $source_helper"
        exit 1
    }
    if [[ -e "$destination_helper" || -L "$destination_helper" ]]; then
        /bin/rm -rf -- "$destination_helper"
    fi
    /usr/bin/ditto "$source_helper" "$destination_helper"
done

/bin/mkdir -p "$notice_dest"
/bin/cp -p "$cef_root/LICENSE.txt" "$notice_dest/LICENSE.txt"
/bin/cp -p "$cef_root/CREDITS.html" "$notice_dest/CREDITS.html"

framework_binary="$framework_dest/Versions/A/Chromium Embedded Framework"
[[ "$(/usr/bin/lipo -archs "$framework_binary")" == "arm64" ]] || {
    print -u2 -- "error: embedded CEF framework is not the pinned ARM64 build"
    exit 1
}

# Xcode signs the outer App after build phases. Nested code copied by this
# phase must be signed first when code signing is enabled. Distribution builds
# deliberately disable Xcode signing and perform the same inside-out sequence
# in package-macos-release.sh with the selected Developer ID identity.
signing_identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
if [[ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" && -n "$signing_identity" ]]; then
    sandbox_library="$framework_dest/Versions/A/Libraries/libcef_sandbox.dylib"
    /usr/bin/codesign --force --sign "$signing_identity" \
        --options runtime --timestamp=none "$sandbox_library"
    /usr/bin/codesign --force --sign "$signing_identity" \
        --options runtime --timestamp=none "$framework_dest"
    for helper in "${helpers[@]}"; do
        helper_path="$frameworks_dir/$helper.app"
        if [[ "$helper" == "EgakiumMac Helper" \
            || "$helper" == "EgakiumMac Helper (GPU)" \
            || "$helper" == "EgakiumMac Helper (Renderer)" ]]; then
            /usr/bin/codesign --force --sign "$signing_identity" \
                --options runtime --timestamp=none \
                --entitlements "$project_root/Apps/EgakiumMac/CEF/CEFJIT.entitlements" \
                "$helper_path"
        else
            /usr/bin/codesign --force --sign "$signing_identity" \
                --options runtime --timestamp=none "$helper_path"
        fi
    done
fi
