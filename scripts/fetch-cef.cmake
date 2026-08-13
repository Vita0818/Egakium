cmake_minimum_required(VERSION 3.21)

get_filename_component(EGAKIUM_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
include("${EGAKIUM_ROOT}/config/cef.cmake")

set(DOWNLOAD_DIR "${EGAKIUM_ROOT}/.deps/downloads")
set(CEF_DIR "${EGAKIUM_ROOT}/.deps/cef")
set(ARCHIVE_PATH "${DOWNLOAD_DIR}/${EGAKIUM_CEF_ARCHIVE}")
set(DISTRIBUTION_DIR
    "${CEF_DIR}/cef_binary_${EGAKIUM_CEF_VERSION}_${EGAKIUM_CEF_PLATFORM}")

file(MAKE_DIRECTORY "${DOWNLOAD_DIR}" "${CEF_DIR}")

if(EXISTS "${ARCHIVE_PATH}")
  file(SHA256 "${ARCHIVE_PATH}" ACTUAL_SHA256)
  if(NOT "${ACTUAL_SHA256}" STREQUAL "${EGAKIUM_CEF_SHA256}")
    message(FATAL_ERROR
            "Existing CEF archive failed SHA-256 verification: ${ARCHIVE_PATH}")
  endif()
else()
  message(STATUS "Downloading official CEF ${EGAKIUM_CEF_VERSION} for ${EGAKIUM_CEF_PLATFORM}")
  file(DOWNLOAD
       "${EGAKIUM_CEF_URL}"
       "${ARCHIVE_PATH}"
       EXPECTED_HASH "SHA256=${EGAKIUM_CEF_SHA256}"
       SHOW_PROGRESS
       STATUS DOWNLOAD_STATUS)
  list(GET DOWNLOAD_STATUS 0 DOWNLOAD_CODE)
  list(GET DOWNLOAD_STATUS 1 DOWNLOAD_MESSAGE)
  if(NOT "${DOWNLOAD_CODE}" EQUAL 0)
    message(FATAL_ERROR "CEF download failed: ${DOWNLOAD_MESSAGE}")
  endif()
endif()

if(EXISTS "${DISTRIBUTION_DIR}/README.txt")
  file(READ "${DISTRIBUTION_DIR}/README.txt" CEF_README LIMIT 2048)
  string(FIND "${CEF_README}" "CEF Version:      ${EGAKIUM_CEF_VERSION}"
         VERSION_POSITION)
  if("${VERSION_POSITION}" EQUAL -1)
    message(FATAL_ERROR
            "Existing CEF directory does not match the pinned version: ${DISTRIBUTION_DIR}")
  endif()
  message(STATUS "CEF is ready at ${DISTRIBUTION_DIR}")
  return()
endif()

if(EXISTS "${DISTRIBUTION_DIR}")
  message(FATAL_ERROR
          "CEF destination exists but is incomplete: ${DISTRIBUTION_DIR}")
endif()

message(STATUS "Extracting ${EGAKIUM_CEF_ARCHIVE}")
file(ARCHIVE_EXTRACT INPUT "${ARCHIVE_PATH}" DESTINATION "${CEF_DIR}")

if(NOT EXISTS "${DISTRIBUTION_DIR}/cmake/FindCEF.cmake")
  message(FATAL_ERROR "CEF extraction did not produce the expected distribution")
endif()

message(STATUS "CEF is ready at ${DISTRIBUTION_DIR}")
