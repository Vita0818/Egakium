cmake_minimum_required(VERSION 3.21)

# Keep generated projects focused on the configurations supported by the
# official CEF binary distribution.
set(CMAKE_CONFIGURATION_TYPES Debug Release)

project(Egakium)

if(NOT APPLE)
  message(FATAL_ERROR "The current Egakium prototype supports macOS only.")
endif()

include("${CMAKE_SOURCE_DIR}/config/cef.cmake")

if(NOT CEF_ROOT)
  set(CEF_ROOT
      "${CMAKE_SOURCE_DIR}/.deps/cef/cef_binary_${EGAKIUM_CEF_VERSION}_${EGAKIUM_CEF_PLATFORM}")
endif()

get_filename_component(CEF_ROOT "${CEF_ROOT}" ABSOLUTE)
if(NOT EXISTS "${CEF_ROOT}/cmake/FindCEF.cmake")
  message(FATAL_ERROR
          "The pinned CEF distribution is missing at ${CEF_ROOT}. "
          "Run: cmake -P scripts/fetch-cef.cmake")
endif()

list(APPEND CMAKE_MODULE_PATH "${CEF_ROOT}/cmake")
find_package(CEF REQUIRED)

add_subdirectory("${CEF_LIBCEF_DLL_WRAPPER_PATH}" libcef_dll_wrapper)

# CEF headers use include paths relative to the distribution root, while the
# Egakium sources use paths relative to this repository root.
include_directories("${CMAKE_SOURCE_DIR}" "${CEF_ROOT}")

add_subdirectory(src/native)

PRINT_CEF_CONFIG()
