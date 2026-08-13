#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
BUILD_DIR="${PROJECT_ROOT}/build/xcode"
GENERATED_PROJECT="${BUILD_DIR}/Egakium.xcodeproj"
ROOT_PROJECT="${PROJECT_ROOT}/Egakium.xcodeproj"
LEGACY_ROOT_PROJECT_TARGET="build/xcode/Egakium.xcodeproj"
ROOT_SCHEME="${ROOT_PROJECT}/xcshareddata/xcschemes/Egakium.xcscheme"
ROOT_WORKSPACE_SETTINGS="${ROOT_PROJECT}/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings"

cmake -P "${PROJECT_ROOT}/scripts/fetch-cef.cmake"

C_COMPILER="$(xcrun --find clang)"
CXX_COMPILER="$(xcrun --find clang++)"

cmake \
  -S "${PROJECT_ROOT}" \
  -B "${BUILD_DIR}" \
  -G Xcode \
  -DPROJECT_ARCH=arm64 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
  -DCMAKE_OSX_SYSROOT=macosx \
  -DCMAKE_C_COMPILER="${C_COMPILER}" \
  -DCMAKE_CXX_COMPILER="${CXX_COMPILER}" \
  -DUSE_SANDBOX=OFF

if [[ ! -f "${GENERATED_PROJECT}/project.pbxproj" ]]; then
  print -u2 "Expected Xcode project was not generated: ${GENERATED_PROJECT}"
  exit 1
fi

if [[ -L "${ROOT_PROJECT}" ]]; then
  if [[ "$(readlink "${ROOT_PROJECT}")" != "${LEGACY_ROOT_PROJECT_TARGET}" ]]; then
    print -u2 "Refusing to replace unexpected symlink: ${ROOT_PROJECT}"
    exit 1
  fi
  unlink "${ROOT_PROJECT}"
elif [[ -e "${ROOT_PROJECT}" ]]; then
  if [[ ! -d "${ROOT_PROJECT}" ]]; then
    print -u2 "Refusing to replace existing path: ${ROOT_PROJECT}"
    exit 1
  fi
fi

cmake -E make_directory "${ROOT_PROJECT}"
cmake -E copy_directory "${GENERATED_PROJECT}" "${ROOT_PROJECT}"

# The generated scheme points at the out-of-tree CMake project. The checked-in
# root project is a real project bundle, so its shared scheme must reference
# itself instead of the backing generation directory.
sed -i '' \
  's#container:build/xcode/Egakium.xcodeproj#container:Egakium.xcodeproj#g' \
  "${ROOT_SCHEME}"

# CMake 4.3.2 currently emits the two quoted DOCTYPE fields without the XML
# separator required by strict parsers. Xcode accepts it, but normalize the
# checked-in root project so both Xcode and generic XML tooling accept it.
sed -i '' \
  's#EN""http://www.apple.com/DTDs/PropertyList-1.0.dtd#EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd#' \
  "${ROOT_WORKSPACE_SETTINGS}"

if [[ -L "${ROOT_PROJECT}" || ! -f "${ROOT_PROJECT}/project.pbxproj" ]]; then
  print -u2 "Expected a physical root Xcode project: ${ROOT_PROJECT}"
  exit 1
fi

print "Generated physical root project ${ROOT_PROJECT}"
print "Open it with: open ${ROOT_PROJECT}"
