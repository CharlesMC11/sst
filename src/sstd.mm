#include <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>
#include <sysexits.h>

#include <climits>
#include <csignal>
#include <cstdlib>
#include <format>
#include <iostream>
#include <print>
#include <string>
#include <vector>

#include "inspector.hh"
#include "memory.hh"
#include "processor.hh"
#include "signal_handler.hh"
#include "sorter.hh"
#include "stream_context.hh"

// TODO: Use os/log.h

std::string get_os_version();

int main(const int argc, const char* const argv[])
{
    if (argc < 7) [[unlikely]] {
        std::println(std::cerr,
                "Usage: {} <exiftool_path> <input_dir> <output_dir> "
                "<tmp_dir> <arg_files_dir> <hw_model>",
                argv[0]);
        return EX_USAGE;
    }

    const char* const exiftool_path{argv[1]};
    const char* const input_dir{argv[2]};
    const char* const output_dir{argv[3]};
    const char* const tmp_dir{argv[4]};
    const char* const arg_files_dir{argv[5]};
    const char* const hw_model{argv[6]};

    std::println("[sstd] Starting daemon…");

    // Prepare configurations to pass to ExifTool

    const sst::image::metadata metadata{
            output_dir, arg_files_dir, hw_model, ::get_os_version()};

    std::println("[sstd] Initializing processor…");
    sst::processor processor{exiftool_path, metadata};
    std::println("[sstd] Initialized processor with metadata:\n\tOutput "
                 "Directory: {}\n\tArg Files Directory: {}\n\tHardware: "
                 "{}\n\tSoftware: {}\n\tTimezone: {}",
            metadata.output_dir, metadata.arg_files_dir, metadata.hardware,
            metadata.software, metadata.timezone);

    // Prepare configurations to pass to FSEventStream

    // TODO: Streamline `monitor`

    const ::dispatch_queue_t queue{::dispatch_get_main_queue()};

    std::println("[sstd] Initializing watcher…");
    sst::stream_context monitor{
            sst::inspector::scan_directory, queue, processor, input_dir};
    std::println("[sstd] Initialized to watch: {}.", input_dir);

    // Prepare signal handlers for teardown

    const sst::runtime::context context{queue, monitor};
    sst::runtime::register_signal_handler(SIGTERM, context);
    sst::runtime::register_signal_handler(SIGINT, context);

    // Start main loop

    std::println("[sstd] Dispatching. Press CTRL-C to stop.");
    ::dispatch_main();
}

inline std::string get_os_version()
{
    const NSOperatingSystemVersion os_ver{
            [NSProcessInfo processInfo].operatingSystemVersion};

    return std::format("{}.{}.{}", os_ver.majorVersion, os_ver.minorVersion,
            os_ver.patchVersion);
}
