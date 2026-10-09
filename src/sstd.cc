#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#include <sysexits.h>

#include <bit>
#include <csignal>
#include <format>
#include <iostream>
#include <print>
#include <string>

#include "orchestrator.hh"
#include "processor.hh"
#include "signal_handler.hh"
#include "stream_context.hh"

// TODO: Use os/log.h

static inline constexpr std::size_t kAvgFilenameLength{45UZ};
static inline constexpr std::size_t kAvgFileCount{16UZ};

int main(const int argc, const char* const argv[])
{
    // Parse CLI Arguments / plist Config
    if (argc < 8) [[unlikely]] {
        std::println(std::cerr,
                "Usage: {} <exiftool_path> <input_dir> <output_dir> "
                "<arg_files_dir> <hw_model> <max_retries> <latency>",
                argv[0]);
        return EX_USAGE;
    }

    std::println("[sstd] Starting daemon…");

    const char* const exiftool_path{argv[1]};
    const char* const input_dir{argv[2]};
    const char* const output_dir{argv[3]};
    const char* const arg_files_dir{argv[4]};
    const char* const hw_model{argv[5]};
    const auto max_retries{static_cast<unsigned>(std::stoi(argv[6]))};
    const double latency{std::stod(argv[7])};

    const std::size_t min_buffer_size{
            std::strlen(input_dir) + kAvgFilenameLength};
    const std::size_t init_reserve_size{
            std::bit_ceil(min_buffer_size * kAvgFileCount)};

    // Prepare configurations to pass to ExifTool
    const sst::image::metadata metadata{
            input_dir, output_dir, arg_files_dir, hw_model};

    std::println("[sstd] Initializing processor…");
    sst::processor processor{
            exiftool_path, metadata, max_retries, init_reserve_size * 2UZ};

    const int dir_fd{::open(input_dir, sst::kIOFlags | O_DIRECTORY)};
    if (dir_fd == -1) [[unlikely]] {
        throw std::system_error{errno, std::generic_category(),
                std::format("[sstd] Failed to open directory: '{}'\n.",
                        input_dir)};
    }

    std::string buffer;
    buffer.reserve(init_reserve_size);

    sst::orchestrator orchestrator{
            processor, input_dir, dir_fd, buffer, max_retries};

    // Initial cleanup
    if (!orchestrator.cleanup()) [[unlikely]] {
        throw std::system_error{errno, std::generic_category(),
                std::format("[sstd] Encountered errors while cleaning up "
                            "directory: '{}'.\n.",
                        input_dir)};
    }

    // Prepare configurations to pass to FSEventStream
    const ::dispatch_queue_t queue{::dispatch_get_main_queue()};

    std::println("[sstd] Initializing watcher…");
    sst::stream_context stream_ctx{orchestrator, queue, latency};
    std::println("[sstd] Initialized to watch directory: '{}'.", input_dir);

    // Prepare signal handlers for teardown
    sst::signals::register_handler(SIGTERM, queue);
    sst::signals::register_handler(SIGINT, queue);

    // Start main loop
    std::println("[sstd] Dispatching… Press CTRL-C to stop.");
    ::CFRunLoopRun();

    // Stop & Invalidate FSEventStream
    stream_ctx.shutdown();

    // Cleanup
    const bool graceful_cleanup{orchestrator.cleanup()};
    if (!graceful_cleanup) [[unlikely]] {
        std::fprintf(stderr,
                "[sstd] Encountered errors while cleaning up "
                "directory: '%s'\n.",
                input_dir);
    }

    const bool graceful_close{::close(dir_fd) != -1};
    if (!graceful_close) [[unlikely]] {
        std::fprintf(stderr, "[sstd] Failed to close directory: '%s'\n.",
                input_dir);
    }

    // Shutdown
    const bool graceful_shutdown{processor.shutdown()};
    if (!graceful_shutdown) [[unlikely]] {
        std::fprintf(stderr,
                "[sstd] Processor failed to shut down "
                "gracefully.\n");
    }

    return graceful_cleanup && graceful_close && graceful_shutdown ? EX_OK
                                                                   : EX_OSERR;
}
