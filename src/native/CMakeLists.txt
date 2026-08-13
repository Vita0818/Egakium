set(EGAKIUM_SRCS
  egakium_app.h
  egakium_app.mm
  egakium_client.h
  egakium_client.cc
  mac/egakium_main.mm
)

set(EGAKIUM_HELPER_SRCS
  mac/egakium_helper.cc
)

set(CEF_TARGET "Egakium")
set(CEF_HELPER_TARGET "Egakium_Helper")
set(CEF_HELPER_OUTPUT_NAME "Egakium Helper")

SET_CEF_TARGET_OUT_DIR()

option(OPTION_USE_ARC "Build Egakium with Automatic Reference Counting." ON)
if(OPTION_USE_ARC)
  list(APPEND CEF_COMPILER_FLAGS -fobjc-arc)
endif()

set(CEF_APP "${CEF_TARGET_OUT_DIR}/${CEF_TARGET}.app")
set(EXECUTABLE_NAME "${CEF_TARGET}")
set(PRODUCT_NAME "${CEF_TARGET}")

add_executable(${CEF_TARGET} MACOSX_BUNDLE ${EGAKIUM_SRCS})
SET_EXECUTABLE_TARGET_PROPERTIES(${CEF_TARGET})
add_dependencies(${CEF_TARGET} libcef_dll_wrapper)
target_link_libraries(${CEF_TARGET} libcef_dll_wrapper ${CEF_STANDARD_LIBS})
set_target_properties(${CEF_TARGET} PROPERTIES
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/mac/Info.plist.in"
  CLANG_ENABLE_OBJC_ARC "YES"
  XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
  XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.vitemis.egakium"
  XCODE_GENERATE_SCHEME TRUE
  XCODE_SCHEME_WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
)

COPY_MAC_FRAMEWORK("${CEF_TARGET}" "${CEF_BINARY_DIR}" "${CEF_APP}")

foreach(_suffix_list ${CEF_HELPER_APP_SUFFIXES})
  string(REPLACE ":" ";" _suffix_list ${_suffix_list})
  list(GET _suffix_list 0 _name_suffix)
  list(GET _suffix_list 1 _target_suffix)
  list(GET _suffix_list 2 _plist_suffix)

  set(_helper_target "${CEF_HELPER_TARGET}${_target_suffix}")
  set(_helper_output_name "${CEF_HELPER_OUTPUT_NAME}${_name_suffix}")
  set(_helper_info_plist
      "${CMAKE_CURRENT_BINARY_DIR}/helper-Info${_target_suffix}.plist")

  file(READ "${CMAKE_CURRENT_SOURCE_DIR}/mac/helper-Info.plist.in"
       _plist_contents)
  string(REPLACE "\${EXECUTABLE_NAME}" "${_helper_output_name}"
         _plist_contents ${_plist_contents})
  string(REPLACE "\${PRODUCT_NAME}" "${_helper_output_name}"
         _plist_contents ${_plist_contents})
  string(REPLACE "\${BUNDLE_ID_SUFFIX}" "${_plist_suffix}"
         _plist_contents ${_plist_contents})
  file(WRITE ${_helper_info_plist} ${_plist_contents})

  add_executable(${_helper_target} MACOSX_BUNDLE ${EGAKIUM_HELPER_SRCS})
  SET_EXECUTABLE_TARGET_PROPERTIES(${_helper_target})
  add_dependencies(${_helper_target} libcef_dll_wrapper)
  target_link_libraries(${_helper_target}
                        libcef_dll_wrapper ${CEF_STANDARD_LIBS})
  set_target_properties(${_helper_target} PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${_helper_info_plist}"
    OUTPUT_NAME "${_helper_output_name}"
    CLANG_ENABLE_OBJC_ARC "YES"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER
      "com.vitemis.egakium.helper${_plist_suffix}"
  )

  add_dependencies(${CEF_TARGET} "${_helper_target}")
  add_custom_command(
    TARGET ${CEF_TARGET}
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CEF_TARGET_OUT_DIR}/${_helper_output_name}.app"
            "${CEF_APP}/Contents/Frameworks/${_helper_output_name}.app"
    VERBATIM
  )
endforeach()

# Preserve the canvas/ directory inside the bundle so the HTML can later grow
# into a multi-file web application without changing native code.
add_custom_command(
  TARGET ${CEF_TARGET}
  POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E make_directory
          "${CEF_APP}/Contents/Resources/canvas"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
          "${CMAKE_SOURCE_DIR}/src/canvas/index.html"
          "${CEF_APP}/Contents/Resources/canvas/index.html"
  VERBATIM
)
