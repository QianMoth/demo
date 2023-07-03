# The MIT License (MIT)
#
# Copyright (c) 2018 Nathan Osman
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
# documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit
# persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
# Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Widgets) # 识别是Qt6还是Qt5

# Retrieve the absolute path to qmake and then use that path to find the windeployqt and macdeployqt binaries
get_target_property(_qmake_executable Qt${QT_VERSION_MAJOR}::qmake IMPORTED_LOCATION)
get_filename_component(_qt_bin_dir "${_qmake_executable}" DIRECTORY)

find_program(WINDEPLOYQT_EXECUTABLE windeployqt HINTS "${_qt_bin_dir}")
if(WIN32 AND NOT WINDEPLOYQT_EXECUTABLE)
  message(FATAL_ERROR "windeployqt not found")
endif()

find_program(MACDEPLOYQT_EXECUTABLE macdeployqt HINTS "${_qt_bin_dir}")
if(APPLE AND NOT MACDEPLOYQT_EXECUTABLE)
  message(FATAL_ERROR "macdeployqt not found")
endif()

# Add commands that copy the required Qt files to the same directory as the target after being built as well as
# including them in final installation
function(windeployqt target)

  # Run windeployqt immediately after build
  # windeployqt error when creating translations https://bugreports.qt.io/browse/QTBUG-112204

  install(CODE
    "
    execute_process(
        COMMAND \"${CMAKE_COMMAND}\" -E env PATH=\"${_qt_bin_dir}\" \"${WINDEPLOYQT_EXECUTABLE}\" $<TARGET_FILE:${target}>
        OUTPUT_VARIABLE output_var
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    MESSAGE(\"QT DIR : ${_qt_bin_dir}\")
    MESSAGE(\"${WINDEPLOYQT_EXECUTABLE} $<TARGET_FILE:${target}>\")
    "
  )

  # windeployqt doesn't work correctly with the system runtime libraries, so we fall back to one of CMake's own modules
  # for copying them over

  # Doing this with MSVC 2015 requires CMake 3.6+
  if((MSVC_VERSION VERSION_EQUAL 1900 OR MSVC_VERSION VERSION_GREATER 1900) AND CMAKE_VERSION VERSION_LESS "3.6")
    message(WARNING "Deploying with MSVC 2015+ requires CMake 3.6+")
  endif()

  set(CMAKE_INSTALL_UCRT_LIBRARIES TRUE)
  include(InstallRequiredSystemLibraries)
endfunction()

# Add commands that copy the required Qt files to the application bundle represented by the target.
function(macdeployqt target)
  install(CODE
    "
    execute_process(
        COMMAND \"${MACDEPLOYQT_EXECUTABLE}\" \"$<TARGET_FILE_DIR:${target}>/../..\"
        OUTPUT_VARIABLE output_var
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    MESSAGE(\"${MACDEPLOYQT_EXECUTABLE} $<TARGET_FILE_DIR:${target}>/../..\")
    execute_process(
      COMMAND codesign --force --deep --sign - $<TARGET_FILE:${target}>
      OUTPUT_VARIABLE output_var
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    "
  )
endfunction()

function(deployqt target)
  if(WIN32)
    windeployqt(${target})
  elseif(APPLE)
    macdeployqt(${target})
  else()
    message(STATUS "This platform is not currently supported")
  endif()
endfunction()

mark_as_advanced(WINDEPLOYQT_EXECUTABLE MACDEPLOYQT_EXECUTABLE)
