#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
BUILD_DIR="${PROJECT_ROOT}/build/cef"
APP_PATH="${BUILD_DIR}/src/native/Release/Egakium.app"

cmake \
  -S "${PROJECT_ROOT}" \
  -B "${BUILD_DIR}" \
  -G Ninja \
  -DPROJECT_ARCH=arm64 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
  -DUSE_SANDBOX=OFF

cmake --build "${BUILD_DIR}" --target Egakium --parallel

if [[ ! -x "${APP_PATH}/Contents/MacOS/Egakium" ]]; then
  print -u2 "Expected application was not generated: ${APP_PATH}"
  exit 1
fi

print "Built ${APP_PATH}"
