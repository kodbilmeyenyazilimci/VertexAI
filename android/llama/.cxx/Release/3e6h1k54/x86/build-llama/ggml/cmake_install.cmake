# Install script for directory: C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "C:/Program Files (x86)/ai")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Install shared libraries without execute permission?
if(NOT DEFINED CMAKE_INSTALL_SO_NO_EXE)
  set(CMAKE_INSTALL_SO_NO_EXE "0")
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "TRUE")
endif()

# Set default install directory permissions.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "C:/Users/Dell/AppData/Local/Android/Sdk/ndk/25.1.8937393/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-objdump.exe")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/Users/Dell/AndroidStudioProjects/llama.cpp/examples/ai/android/llama/.cxx/Release/3e6h1k54/x86/build-llama/ggml/src/cmake_install.cmake")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so")
    file(RPATH_CHECK
         FILE "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so"
         RPATH "")
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE SHARED_LIBRARY FILES "C:/Users/Dell/AndroidStudioProjects/llama.cpp/examples/ai/build/llama/intermediates/cxx/Release/3e6h1k54/obj/x86/libggml.so")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "C:/Users/Dell/AppData/Local/Android/Sdk/ndk/25.1.8937393/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-strip.exe" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so")
    endif()
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include" TYPE FILE FILES
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-alloc.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-backend.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-blas.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-cann.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-cuda.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-kompute.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-metal.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-rpc.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-sycl.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-vulkan.h"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so")
    file(RPATH_CHECK
         FILE "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so"
         RPATH "")
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE SHARED_LIBRARY FILES "C:/Users/Dell/AndroidStudioProjects/llama.cpp/examples/ai/build/llama/intermediates/cxx/Release/3e6h1k54/obj/x86/libggml.so")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so")
    if(CMAKE_INSTALL_DO_STRIP)
      execute_process(COMMAND "C:/Users/Dell/AppData/Local/Android/Sdk/ndk/25.1.8937393/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-strip.exe" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libggml.so")
    endif()
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include" TYPE FILE FILES
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-alloc.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-backend.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-blas.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-cann.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-cuda.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-kompute.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-metal.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-rpc.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-sycl.h"
    "C:/Users/Dell/AndroidStudioProjects/llama.cpp/ggml/include/ggml-vulkan.h"
    )
endif()

