# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(audio_dsp_library VERSION 0.0.1 LANGUAGES CXX)

add_library(audio_dsp SHARED
  "audio_dsp.cpp"
)

set_target_properties(audio_dsp PROPERTIES
  PUBLIC_HEADER audio_dsp.h
  OUTPUT_NAME "audio_dsp"
)

target_compile_definitions(audio_dsp PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(audio_dsp PRIVATE "-Wl,-z,max-page-size=16384")
endif()
