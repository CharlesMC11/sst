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

#include "file_monitor.hh"
#include "inspector.hh"
#include "memory.hh"
#include "processor.hh"
#include "runtime_context.hh"
#include "signal_handler.hh"
#include "sorter.hh"

int main(const int argc, const char* argv[])
{
    if (argc < 5) {
        std::cerr << "Usage: " << argv[0]
                  << " <input_dir> <output_dir> <hardware> <arg_files_dir>\n";
        return EX_USAGE;
    }
    const char* input_dir{argv[1]};

    std::cout << "[sstd] Starting daemon…" << std::endl;

    const NSOperatingSystemVersion os_version {
            [NSProcessInfo processInfo].operatingSystemVersion};

    const sst::image::metadata metadata{.output_dir{argv[2]},
            .hardware{argv[3]},
            .software{std::format("{}.{}.{}", os_version.majorVersion,
                    os_version.minorVersion, os_version.patchVersion)},
            .timezone{"-07:00"},
            .arg_files_dir{argv[4]}};

    std::cout << "[sstd] Initializing processor…" << std::endl;
    const sst::processor processor{metadata};
    std::cout << "[sstd] Initialized processor with metadata:\n"
              << "\tOutput Directory: " << metadata.output_dir << "\n"
              << "\tHardware: " << metadata.hardware << "\n"
              << "\tSoftware: " << metadata.software << "\n"
              << "\tTimezone: " << metadata.timezone << "\n"
              << "\tArg Files Directory: " << metadata.arg_files_dir
              << std::endl;

    const sst::memory::CFPtr<CFMutableArrayRef> buffer{
            CFArrayCreateMutable(nullptr, 0, &kCFTypeArrayCallBacks)};

    const dispatch_queue_t queue{dispatch_get_main_queue()};

    std::cout << "[sstd] Initializing watcher…" << std::endl;
    const sst::filesystem::monitor monitor{
            queue, buffer.get(), input_dir, processor, sst::inspector::scan_directory};
    monitor.start();
    std::cout << "[sstd] Initialized to watch '" << input_dir << ".'"
              << std::endl;

    const sst::runtime::context context{queue, buffer.get(), monitor};
    sst::runtime::register_signal_handler(SIGTERM, context);
    sst::runtime::register_signal_handler(SIGINT, context);


    std::cout << "[sstd] Dispatching. Press CTRL-C to stop." << std::endl;
    dispatch_main();
}
