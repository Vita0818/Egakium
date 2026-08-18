#!/bin/zsh

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
project_root="$(cd "$script_dir/.." && pwd -P)"
configuration="${1:-${CONFIGURATION:-Debug}}"

case "$configuration" in
    Debug|Release)
        ;;
    *)
        print -u2 -- "error: unsupported CEF configuration: $configuration"
        exit 1
        ;;
esac

cef_config="$project_root/config/cef.cmake"
[[ -f "$cef_config" ]] || {
    print -u2 -- "error: missing pinned CEF configuration: $cef_config"
    exit 1
}

cef_version="$(/usr/bin/awk -F'"' \
    '/^set\(EGAKIUM_CEF_VERSION / { print $2; exit }' "$cef_config")"
cef_platform="$(/usr/bin/awk -F'"' \
    '/^set\(EGAKIUM_CEF_PLATFORM / { print $2; exit }' "$cef_config")"
cef_sha256="$(/usr/bin/awk -F'"' \
    '/^[[:space:]]*"[0-9a-f]+"\)$/ { print $2; exit }' "$cef_config")"

[[ -n "$cef_version" && "$cef_platform" == "macosarm64" \
    && ${#cef_sha256} -eq 64 && "$cef_sha256" != *[^0-9a-f]* ]] || {
    print -u2 -- "error: invalid pinned CEF configuration"
    exit 1
}

cef_archive_name="cef_binary_${cef_version}_${cef_platform}.tar.bz2"
cef_root="$project_root/.deps/cef/${cef_archive_name%.tar.bz2}"
cef_archive="$project_root/.deps/downloads/$cef_archive_name"
framework="$cef_root/$configuration/Chromium Embedded Framework.framework"
build_dir="$project_root/build/egakium-cef-runtime"

for required in \
    "$cef_archive" \
    "$cef_root/LICENSE.txt" \
    "$cef_root/CREDITS.html" \
    "$cef_root/include/cef_app.h" \
    "$cef_root/include/wrapper/cef_library_loader.h" \
    "$cef_root/libcef_dll/CMakeLists.txt" \
    "$framework/Chromium Embedded Framework" \
    "$framework/Libraries/libcef_sandbox.dylib"; do
    [[ -e "$required" ]] || {
        print -u2 -- "error: required official CEF asset is missing: $required"
        exit 1
    }
done

architectures="$(/usr/bin/lipo -archs \
    "$framework/Chromium Embedded Framework")"
[[ "$architectures" == "arm64" ]] || {
    print -u2 -- "error: pinned CEF framework must be exactly arm64; got: $architectures"
    exit 1
}

/bin/mkdir -p "$build_dir"
integrity_stamp="$build_dir/.archive-$cef_sha256.verified"
if [[ ! -f "$integrity_stamp" || "$cef_archive" -nt "$integrity_stamp" \
    || "$cef_config" -nt "$integrity_stamp" ]]; then
    actual_sha256="$(/usr/bin/shasum -a 256 "$cef_archive" \
        | /usr/bin/awk '{print $1}')"
    [[ "$actual_sha256" == "$cef_sha256" ]] || {
        print -u2 -- "error: official CEF archive SHA-256 mismatch"
        print -u2 -- "expected: $cef_sha256"
        print -u2 -- "actual:   $actual_sha256"
        exit 1
    }
    /usr/bin/touch "$integrity_stamp"
fi

cmake_path="$(command -v cmake || true)"
ninja_path="$(command -v ninja || true)"
[[ -n "$cmake_path" && -n "$ninja_path" ]] || {
    print -u2 -- "error: CMake and Ninja are required to build the official CEF wrapper"
    exit 1
}

marketing_version="$(/usr/bin/awk -F'"' \
    '/^[[:space:]]*MARKETING_VERSION:/ { print $2; exit }' \
    "$project_root/project.yml")"
build_number="$(/usr/bin/awk -F'"' \
    '/^[[:space:]]*CURRENT_PROJECT_VERSION:/ { print $2; exit }' \
    "$project_root/project.yml")"
[[ -n "$marketing_version" && -n "$build_number" ]] || {
    print -u2 -- "error: project version metadata is unavailable"
    exit 1
}

"$cmake_path" \
    -S "$project_root/Apps/EgakiumMac/CEF" \
    -B "$build_dir" \
    -G Ninja \
    -DCEF_ROOT="$cef_root" \
    -DPROJECT_ARCH=arm64 \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_BUILD_TYPE="$configuration" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=26.0 \
    -DUSE_SANDBOX=ON \
    -DEGAKIUM_MARKETING_VERSION="$marketing_version" \
    -DEGAKIUM_BUILD_NUMBER="$build_number"

"$cmake_path" --build "$build_dir" \
    --target egakium_cef_runtime \
    --parallel

for product in \
    "$build_dir/libEgakiumCEFHost.a" \
    "$build_dir/libcef_dll_wrapper/libcef_dll_wrapper.a" \
    "$build_dir/$configuration/EgakiumMac Helper.app" \
    "$build_dir/$configuration/EgakiumMac Helper (Alerts).app" \
    "$build_dir/$configuration/EgakiumMac Helper (GPU).app" \
    "$build_dir/$configuration/EgakiumMac Helper (Plugin).app" \
    "$build_dir/$configuration/EgakiumMac Helper (Renderer).app"; do
    [[ -e "$product" ]] || {
        print -u2 -- "error: expected CEF build product is missing: $product"
        exit 1
    }
done
