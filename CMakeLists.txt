cmake_minimum_required(VERSION 4.1)

set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if (NOT DEFINED CMAKE_OSX_ARCHITECTURES)
    set(CMAKE_OSX_ARCHITECTURES "arm64")
endif ()

project(sst ASM CXX OBJCXX)

include(CheckIPOSupported)

option(ENABLE_LTO "Enable ThinLTO in Release builds" ON)

# Compiler Flags

set(SST_COMMON_COMPILE_OPTIONS
        -D_FORTIFY_SOURCE=2
        -mbranch-protection=standard
        -falign-functions=16
        -fcolor-diagnostics
        -fstrict-aliasing
        -Wall
        -Wextra
        -Wpedantic
)

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    add_compile_definitions(DEBUG_MODE)
    list(APPEND SST_COMMON_COMPILE_OPTIONS
            -O0
            -g
#            -fsanitize=address
#            -fsanitize=undefined
            -fno-omit-frame-pointer
            -fno-optimize-sibling-calls
    )
#    set(SST_SANITIZER_LINK_FLAGS -fsanitize=address -fsanitize=undefined)
else ()
    add_compile_definitions(NDEBUG)
    list(APPEND SST_COMMON_COMPILE_OPTIONS -O2 -fomit-frame-pointer)
    if (ENABLE_LTO)
        check_ipo_supported(RESULT ipo_supported)
        if (ipo_supported)
            set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
        endif ()
    endif ()
endif ()

# Frameworks

find_library(CORE_FOUNDATION_FRAMEWORK CoreFoundation REQUIRED)
find_library(CORE_SERVICES_FRAMEWORK CoreServices REQUIRED)
find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)

# Core Library

add_library(sstlib STATIC
        src/filter.cc
        src/filter.hh
        src/memory.hh
        src/metadata.hh
        src/notifier.hh
        src/notifier.mm
        src/processor.hh
        src/processor.mm
        src/orchestrator.hh
        src/orchestrator.cc
        src/signal_handler.cc
        src/signal_handler.hh
        src/signatures.s
        src/stream_context.cc
        src/stream_context.hh
)

target_include_directories(sstlib PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/tests>
)

target_compile_options(sstlib PRIVATE
        ${SST_COMMON_COMPILE_OPTIONS}
        $<$<COMPILE_LANGUAGE:CXX>:-fno-rtti>
)

target_link_libraries(sstlib PUBLIC
        ${CORE_FOUNDATION_FRAMEWORK}
        ${CORE_SERVICES_FRAMEWORK}
        ${FOUNDATION_FRAMEWORK}
)

if (SST_SANITIZER_LINK_FLAGS)
    target_link_options(sstlib PUBLIC ${SST_SANITIZER_LINK_FLAGS})
endif ()

# Executable

add_executable(sstd src/sstd.cc)

target_compile_options(sstd PRIVATE
        ${SST_COMMON_COMPILE_OPTIONS}
        $<$<COMPILE_LANGUAGE:CXX>:-fno-rtti>
)

target_link_libraries(sstd PRIVATE sstlib)

target_link_options(sstd PRIVATE
        -Wl,-dead_strip
        -Wl,-no_warn_duplicate_libraries
)

add_custom_command(
    TARGET sstd POST_BUILD
    COMMAND codesign --force --options runtime --entitlements "${CMAKE_CURRENT_SOURCE_DIR}/Entitlements.plist" -s - $<TARGET_FILE:sstd>
)

# Testing

include(FetchContent)
FetchContent_Declare(
        googletest
        URL https://github.com/google/googletest/archive/03597a01ee50ed33e9dfd640b249b4be3799d395.zip
)
FetchContent_MakeAvailable(googletest)

enable_testing()
add_executable(tests
        tests/test.hh
        tests/test_filter/test_filter.cc
        tests/test_orchestrator.cc
        tests/test_processor/test_processor.cc
        tests/test_stream_context.cc
)

target_compile_options(tests PRIVATE ${SST_COMMON_COMPILE_OPTIONS})

target_compile_definitions(tests PRIVATE
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

target_link_libraries(tests PRIVATE sstlib GTest::gtest_main)

include(GoogleTest)
gtest_discover_tests(tests)

# Launchd

execute_process(
        COMMAND command -v exiftool
        OUTPUT_VARIABLE EXIFTOOL
        OUTPUT_STRIP_TRAILING_WHITESPACE
)

set(SERVICE_NAME "sst")
set(AUTHOR "charlesmc")
set(RDNN "me.${AUTHOR}.${SERVICE_NAME}")

set(WORKBENCH "/Volumes/Workbench")
set(BIN_DIR "${WORKBENCH}/${SERVICE_NAME}")
set(INPUT_DIR "${WORKBENCH}/Screenshots")
set(OUTPUT_DIR "$ENV{HOME}/MyFiles/Pictures/Screenshots")
set(ARG_FILES_DIR "$ENV{HOME}/.local/share/exiftool")

set(AGENT_NAME "${SERVICE_NAME}d")
set(PLIST_NAME "${RDNN}.plist")

set(MAX_RETRIES 3)
set(LATENCY 0.25)

execute_process(
        COMMAND /bin/sh -c "system_profiler SPHardwareDataType | sed -En 's/^.*Model Name: //p'"
        OUTPUT_VARIABLE HW_MODEL
        OUTPUT_STRIP_TRAILING_WHITESPACE
)

configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/${SERVICE_NAME}.plist.template"
        "${CMAKE_CURRENT_BINARY_DIR}/${PLIST_NAME}"
)
