#!/bin/zsh

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
project_root="$(cd "$script_dir/.." && pwd -P)"
intatis_root="$(cd "$project_root/../../Intatis" && pwd -P)"
app_bundle="${1:-}"
configuration="${2:-Debug}"

fail() {
    print -u2 -- "error: $*"
    exit 1
}

[[ "$intatis_root" == "/Users/vita/Vitemis/Intatis" ]] \
    || fail "../../Intatis resolved to unexpected root: $intatis_root"
[[ -n "$app_bundle" && "$app_bundle" == *.app ]] \
    || fail "usage: scripts/embed-intatis-codex-runtime.sh <app-bundle> <configuration>"
[[ -d "$app_bundle" && ! -L "$app_bundle" ]] \
    || fail "target App bundle is missing or unsafe: $app_bundle"

architecture="arm64"
default_runtime_root="$intatis_root/.intatis/runtime-kit/0.66/CodexRuntime/$architecture"
runtime_root="${EGAKIUM_CODEX_RUNTIME_ROOT:-$default_runtime_root}"
[[ "$runtime_root" == /* ]] \
    || fail "EGAKIUM_CODEX_RUNTIME_ROOT must be an absolute path"
[[ -d "$runtime_root" && ! -L "$runtime_root" ]] \
    || fail "exact Intatis Codex runtime is unavailable: $runtime_root"
runtime_root="$(cd "$runtime_root" && pwd -P)"

"$project_root/scripts/validate-codex-runtime.sh" \
    "$runtime_root" "$architecture" "" static

resources="$app_bundle/Contents/Resources"
destination_parent="$resources/CodexRuntime"
destination="$destination_parent/$architecture"
/bin/mkdir -p "$resources" "$destination_parent"

# The target is a build product owned by this invocation. Replace only the
# exact architecture directory after validating the source closure.
if [[ -e "$destination" || -L "$destination" ]]; then
    /bin/rm -rf -- "$destination"
fi
/usr/bin/ditto "$runtime_root" "$destination"
/bin/chmod 0755 "$destination/codex"

"$project_root/scripts/validate-codex-runtime.sh" \
    "$destination" "$architecture" "" static

print -- "Embedded exact Intatis Codex runtime $architecture for $configuration"
