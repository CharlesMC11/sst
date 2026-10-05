cmake_minimum_required(VERSION 4.1)
project(test-sprite-engine ASM CXX OBJCXX)

set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_OSX_ARCHITECTURES "arm64")

find_library(CORE_FOUNDATION_FRAMEWORK CoreFoundation REQUIRED)
find_library(CORE_SERVICES_FRAMEWORK CoreServices REQUIRED)
find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)

add_executable(sstd
        src/sstd.mm
        src/processor.cc
        src/fs_monitor.mm
        src/inspector.cc
        src/signatures.s
        src/sorter.cc
        src/signal_handler.cc
)

target_include_directories(sstd PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(sstd PRIVATE
        ${CORE_FOUNDATION_FRAMEWORK}
        ${CORE_SERVICES_FRAMEWORK}
        ${FOUNDATION_FRAMEWORK}
)