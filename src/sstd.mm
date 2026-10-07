#include <CoreFoundation/CoreFoundation.h>
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

#include "memory.hh"
#include "orchestrator.hh"
#include "processor.hh"
#include "signal_handler.hh"
#include "sorter.hh"
#include "stream_context.hh"

// TODO: Use os/log.h

int main(const int argc, const char* const argv[])
{
    // Parse CLI Arguments / plist Config
    if (argc < 8) [[unlikely]] {
        std::println(std::cerr,
                "Usage: {} <exiftool_path> <input_dir> <output_dir> "
                "<tmp_dir> <arg_files_dir> <hw_model> <max_retries>",
                argv[0]);
        return EX_USAGE;
    }

    const char* const exiftool_path{argv[1]};
    const char* const input_dir{argv[2]};
    const char* const output_dir{argv[3]};
    const char* const tmp_dir{argv[4]};
    const char* const arg_files_dir{argv[5]};
    const char* const hw_model{argv[6]};
    const unsigned max_retries{5U};

    std::println("[sstd] Starting daemon…");

    // Prepare configurations to pass to ExifTool
    const sst::image::metadata metadata{
            input_dir, output_dir, arg_files_dir, hw_model};

    std::println("[sstd] Initializing processor…");
    sst::processor processor{exiftool_path, metadata, max_retries};

    const int dir_fd{::open(input_dir, sst::kIOFlags | O_DIRECTORY)};
    if (dir_fd == -1) [[unlikely]] {
        throw std::system_error{errno, std::generic_category(),
                std::format("[sstd] Failed to open directory: '{}'\n.",
                        input_dir)};
    }

    std::vector<std::string> buffer;

    // Initial cleanup
    if (!sst::orchestrator::cleanup(processor, dir_fd, buffer, max_retries))
            [[unlikely]] {
        throw std::system_error{errno, std::generic_category(),
                std::format("[sstd] Encountered errors while cleaning up "
                            "directory: '{}'.\n.",
                        input_dir)};
    }

    // Prepare configurations to pass to FSEventStream
    const ::dispatch_queue_t queue{::dispatch_get_main_queue()};

    std::println("[sstd] Initializing watcher…");
    sst::stream_context stream_ctx{sst::orchestrator::orchestrate, queue,
            processor, input_dir, dir_fd, max_retries};
    std::println("[sstd] Initialized to watch directory: '{}'.", input_dir);

    // Prepare signal handlers for teardown
    sst::signals::register_handler(SIGTERM, queue);
    sst::signals::register_handler(SIGINT, queue);

    // Start main loop
    std::println("[sstd] Dispatching. Press CTRL-C to stop.");
    ::CFRunLoopRun();

    // Stop & Invalidate FSEventStream
    stream_ctx.shutdown();

    // Cleanup
    const bool graceful_cleanup{sst::orchestrator::cleanup(
            processor, dir_fd, stream_ctx.buffer(), processor.max_retries())};
    if (!graceful_cleanup) [[unlikely]] {
        std::fprintf(stderr,
                "[sstd] Encountered errors while cleaning up "
                "directory: '%s'\n.",
                input_dir);
    }

    const bool graceful_close{::close(dir_fd) != -1};
    if (!graceful_close) [[unlikely]] {
        std::fprintf(
                stderr, "[sstd] Failed to close directory: '%s'\n", input_dir);
    }

    // Shutdown
    const bool graceful_shutdown{processor.shutdown()};
    if (!graceful_shutdown) [[unlikely]] {
        std::fprintf(stderr,
                "[sstd] Processor failed to shut down "
                "gracefully.\n");
    }

    return (graceful_cleanup && graceful_close && graceful_shutdown)
            ? EX_OK
            : EX_OSERR;
}
