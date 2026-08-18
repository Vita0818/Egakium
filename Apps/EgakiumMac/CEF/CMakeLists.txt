cmake_minimum_required(VERSION 3.21)

project(EgakiumCEF LANGUAGES C CXX OBJC OBJCXX)

if(NOT CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  message(FATAL_ERROR "Egakium Canvas CEF is macOS-only")
endif()
if(NOT PROJECT_ARCH STREQUAL "arm64")
  message(FATAL_ERROR "The pinned Egakium CEF distribution is ARM64-only")
endif()
if(NOT USE_SANDBOX)
  message(FATAL_ERROR "Egakium CEF helpers must be built with the CEF sandbox")
endif()
if(NOT DEFINED EGAKIUM_MARKETING_VERSION OR
   NOT DEFINED EGAKIUM_BUILD_NUMBER)
  message(FATAL_ERROR "Egakium version metadata is required")
endif()

set(CMAKE_CONFIGURATION_TYPES Debug Release CACHE STRING
    "Supported CEF configurations" FORCE)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CEF_ROOT}/cmake")
find_package(CEF REQUIRED)
print_cef_config()

add_subdirectory("${CEF_LIBCEF_DLL_WRAPPER_PATH}" libcef_dll_wrapper)

# Compile the official CEF external-pump implementation directly from the
# pinned distribution. EgakiumCEFBridge.mm only wires those APIs to the
# existing AppKit/SwiftUI lifecycle and Session workspace boundary.
set(EGAKIUM_CEF_HOST_SOURCES
  EgakiumCEFBridge.mm
  "${CEF_ROOT}/tests/shared/browser/main_message_loop.cc"
  "${CEF_ROOT}/tests/shared/browser/main_message_loop_std.cc"
  "${CEF_ROOT}/tests/shared/browser/main_message_loop_external_pump.cc"
  "${CEF_ROOT}/tests/shared/browser/main_message_loop_external_pump_mac.mm"
)

add_library(EgakiumCEFHost STATIC ${EGAKIUM_CEF_HOST_SOURCES})
SET_LIBRARY_TARGET_PROPERTIES(EgakiumCEFHost)
target_compile_options(EgakiumCEFHost PRIVATE
  $<$<COMPILE_LANGUAGE:OBJCXX>:${CEF_COMPILER_FLAGS} ${CEF_CXX_COMPILER_FLAGS} -fobjc-arc>
)
target_include_directories(EgakiumCEFHost PRIVATE "${CEF_ROOT}")
target_link_libraries(EgakiumCEFHost
  libcef_dll_wrapper
  ${CEF_STANDARD_LIBS}
)
set_target_properties(EgakiumCEFHost PROPERTIES
  ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
  OUTPUT_NAME "EgakiumCEFHost"
)

set(EGAKIUM_CEF_HELPERS
  "::"
  " (Alerts):_alerts:.alerts"
  " (GPU):_gpu:.gpu"
  " (Plugin):_plugin:.plugin"
  " (Renderer):_renderer:.renderer"
)

set(EGAKIUM_CEF_HELPER_TARGETS "")
foreach(helper_spec ${EGAKIUM_CEF_HELPERS})
  string(REPLACE ":" ";" helper_parts "${helper_spec}")
  list(GET helper_parts 0 helper_name_suffix)
  list(GET helper_parts 1 helper_target_suffix)
  list(GET helper_parts 2 HELPER_BUNDLE_ID_SUFFIX)

  set(helper_target "EgakiumMacHelper${helper_target_suffix}")
  set(HELPER_EXECUTABLE_NAME "EgakiumMac Helper${helper_name_suffix}")
  set(helper_info "${CMAKE_CURRENT_BINARY_DIR}/Helper-Info${helper_target_suffix}.plist")
  configure_file(Helper-Info.plist.in "${helper_info}" @ONLY)

  add_executable(${helper_target} MACOSX_BUNDLE EgakiumCEFHelperMain.cc)
  SET_EXECUTABLE_TARGET_PROPERTIES(${helper_target})
  target_link_libraries(${helper_target}
    libcef_dll_wrapper
    ${CEF_STANDARD_LIBS}
  )
  set_target_properties(${helper_target} PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${helper_info}"
    OUTPUT_NAME "${HELPER_EXECUTABLE_NAME}"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/${CMAKE_BUILD_TYPE}"
  )
  list(APPEND EGAKIUM_CEF_HELPER_TARGETS ${helper_target})
endforeach()

add_custom_target(egakium_cef_runtime ALL
  DEPENDS EgakiumCEFHost libcef_dll_wrapper ${EGAKIUM_CEF_HELPER_TARGETS}
)
