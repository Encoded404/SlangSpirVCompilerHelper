cmake_minimum_required(VERSION 3.15)

set(PROJECT_NAME "slang-spirv-compiler-helper")
set(CLI_TOOL_TARGET "slang-spirv-compiler")

set(OUTPUT_PATH "${CMAKE_BINARY_DIR}/bin")

project(${PROJECT_NAME} VERSION 1.0 LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

option(ENABLE_LOGGING "Enable header-only logging interface" ON)

option(CLANG_TIDY_ENABLED "Enable Clang-Tidy static analysis" ON)
if(CLANG_TIDY_ENABLED AND NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
  set(CLANG_TIDY_ENABLED OFF)
endif()
if(CLANG_TIDY_ENABLED)
	include(ConfigureClangTidy)
endif()

add_subdirectory(src)
