cmake_minimum_required(VERSION 4.1)
project(sst ASM CXX OBJCXX)

set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_OSX_ARCHITECTURES "arm64")

find_library(CORE_FOUNDATION_FRAMEWORK CoreFoundation REQUIRED)
find_library(CORE_SERVICES_FRAMEWORK CoreServices REQUIRED)
find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)

add_library(sstlib STATIC
        src/metadata.hh
        src/processor.hh
        src/processor.cc
        src/memory.hh
        src/stream_context.hh
        src/stream_context.mm
        src/orchestrator.hh
        src/orchestrator.cc
        src/filter.hh
        src/filter.cc
        src/signatures.s
        src/sorter.hh
        src/sorter.cc
        src/notifier.hh
        src/notifier.mm
        src/signal_handler.hh
        src/signal_handler.cc
)

include_directories(
        src/
        tests/
)

add_executable(sstd
        src/sstd.mm
)

target_link_libraries(sstlib PUBLIC
        ${CORE_FOUNDATION_FRAMEWORK}
        ${CORE_SERVICES_FRAMEWORK}
        ${FOUNDATION_FRAMEWORK}
)

target_link_libraries(sstd PRIVATE
        sstlib
)

include(FetchContent)
FetchContent_Declare(
        googletest
        URL https://github.com/google/googletest/archive/03597a01ee50ed33e9dfd640b249b4be3799d395.zip
)
FetchContent_MakeAvailable(googletest)

enable_testing()
add_executable(test_processor
        tests/test.hh
        tests/test_filter/test_filter.cc
        tests/test_orchestrator.cc
        tests/test_processor/test_processor.cc
        tests/test_sorter.cc
)

target_compile_definitions(test_processor PRIVATE
        TEST_FILTER_HEIC1="${CMAKE_CURRENT_SOURCE_DIR}/tests/test_filter/heic1.bin"
        TEST_FILTER_HEIC2="${CMAKE_CURRENT_SOURCE_DIR}/tests/test_filter/heic2.bin"
        TEST_FILTER_JPEG="${CMAKE_CURRENT_SOURCE_DIR}/tests/test_filter/jpeg.bin"
        TEST_FILTER_PNG="${CMAKE_CURRENT_SOURCE_DIR}/tests/test_filter/png.bin"
        TEST_FILTER_TIFF1="${CMAKE_CURRENT_SOURCE_DIR}/tests/test_filter/tiff1.bin"
        TEST_FILTER_TIFF2="${CMAKE_CURRENT_SOURCE_DIR}/tests/test_filter/tiff2.bin"
        TEST_FILTER_LONG="${CMAKE_CURRENT_SOURCE_DIR}/tests/test_filter/long.bin"
        TEST_FILTER_SHORT="${CMAKE_CURRENT_SOURCE_DIR}/tests/test_filter/short.bin"
        TEST_ORCHESTRATOR_CLEANUP="${CMAKE_CURRENT_SOURCE_DIR}/tests/test_filter"
        TEST_PROCESSOR_IS_RUNNING="${CMAKE_CURRENT_SOURCE_DIR}/tests/test_processor/test_processor_is_running.py"
        TEST_PROCESSOR_SEND="${CMAKE_CURRENT_SOURCE_DIR}/tests/test_processor/test_processor_send.py"
        TEST_PROCESSOR_SEND_FILE="${CMAKE_CURRENT_SOURCE_DIR}/tests/test_processor/test_processor_send.txt"
)

target_link_libraries(test_processor
        sstlib
        GTest::gtest_main
)

include(GoogleTest)
gtest_discover_tests(test_processor)
