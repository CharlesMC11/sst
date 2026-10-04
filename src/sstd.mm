#include <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>
#include <limits.h>
#include <stdlib.h>
#include <sysexits.h>

#include <csignal>
#include <cstdlib>
#include <format>
#include <iostream>
#include <string>
#include <vector>

#include "fs_monitor.hh"
#include "inspector.hh"
#include "memory.hh"
#include "processor.hh"
#include "signal_handler.hh"
#include "sorter.hh"

std::string get_os_version();

int main(const int argc, const char* const argv[])
{
    if (argc < 7) [[unlikely]] {
        std::cerr << "Usage: " << argv[0]
                  << " <exiftool_path> <input_dir> <output_dir> <tmp_dir> "
                     "<arg_files_dir> <hw_model>\n";
        return EX_USAGE;
    }

    const char* const exiftool_path{argv[1]};
    const char* const input_dir{argv[2]};
    const char* const output_dir{argv[3]};
    const char* const tmp_dir{argv[4]};
    const char* const arg_files_dir{argv[5]};
    const char* const hw_model{argv[6]};

    std::cout << "[sstd] Starting daemon…" << std::endl;

    const sst::image::metadata metadata{
            output_dir, arg_files_dir, hw_model, ::get_os_version()};

    std::cout << "[sstd] Initializing processor…" << std::endl;
    sst::processor processor{exiftool_path, metadata};
    std::cout << "[sstd] Initialized processor with metadata:\n"
              << "\tOutput Directory: " << metadata.output_dir << "\n"
              << "\tArg Files Directory: " << metadata.arg_files_dir << "\n"
              << "\tHardware: " << metadata.hardware << "\n"
              << "\tSoftware: " << metadata.software << "\n"
              << "\tTimezone: " << metadata.timezone << std::endl;

    std::vector<std::string> buffer;
    const ::dispatch_queue_t queue{::dispatch_get_main_queue()};

    std::cout << "[sstd] Initializing watcher…" << std::endl;
    sst::fs::monitor monitor{buffer, sst::inspector::scan_directory, queue,
            processor, input_dir};
    monitor.start();
    std::cout << "[sstd] Initialized to watch '" << input_dir << ".'"
              << std::endl;

    const sst::runtime::context context{queue, buffer, monitor};
    sst::runtime::register_signal_handler(SIGTERM, context);
    sst::runtime::register_signal_handler(SIGINT, context);

    std::cout << "[sstd] Dispatching. Press CTRL-C to stop." << std::endl;
    ::dispatch_main();
}

inline std::string get_os_version()
{
    const NSOperatingSystemVersion os_ver{
            [NSProcessInfo processInfo].operatingSystemVersion};

    return std::format("{}.{}.{}", os_ver.majorVersion, os_ver.minorVersion,
            os_ver.patchVersion);
}
