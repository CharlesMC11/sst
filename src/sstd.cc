#include "config.hh"

#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#include <os/log.h>
#include <sysexits.h>

#include <bit>
#include <csignal>
#include <format>
#include <iostream>
#include <string>
#include <system_error>

#include "orchestrator.hh"
#include "processor.hh"
#include "signal_handler.hh"
#include "stream_context.hh"

namespace sst {

    static inline constexpr std::size_t kAvgFilenameLength{45UZ};
    static inline constexpr std::size_t kAvgFileCount{16UZ};

    ::os_log_t g_logger{::os_log_create(kSubsystem, "daemon")};

} // namespace sst

int main(const int argc, const char* const argv[])
{
    // Parse CLI Arguments / plist Config
    if (argc < 7) [[unlikely]] {
        os_log_error(sst::g_logger,
                "Usage: %s <exiftool_path> <input_dir> <output_dir> "
                "<arg_files_dir> <max_retries> <latency>",
                argv[0UZ]);
        return EX_USAGE;
    }

    os_log(sst::g_logger, "[sstd] Starting daemon…");

    const char* const exiftool_path{argv[1UZ]};
    const char* const input_dir{argv[2UZ]};
    const char* const output_dir{argv[3UZ]};
    const char* const arg_files_dir{argv[4UZ]};
    const auto max_retries{static_cast<unsigned>(std::stoi(argv[5UZ]))};
    const double latency{std::stod(argv[6UZ])};

    // Open directory

    const int dir_fd{::open(input_dir, sst::kIOFlags | O_DIRECTORY)};
    if (dir_fd == -1) [[unlikely]] {
        throw std::system_error{errno, std::generic_category(),
                std::format("[sstd] Failed to open directory: '{}'\n.",
                        input_dir)};
    }

    // Prepare configurations to pass to ExifTool
    const sst::exiftool_args exiftool_args{
            dir_fd, exiftool_path, output_dir, arg_files_dir};

    os_log_info(sst::g_logger, "[sstd] Initializing processor…");
    sst::processor processor{exiftool_args, max_retries};

    const std::size_t min_buffer_size{
            std::strlen(input_dir) + sst::kAvgFilenameLength};
    const std::size_t init_reserve_size{
            std::bit_ceil(min_buffer_size * sst::kAvgFileCount)};

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

    os_log_info(sst::g_logger, "[sstd] Initializing watcher…");
    sst::stream_context stream_ctx{orchestrator, queue, latency};
    os_log_info(sst::g_logger, "[sstd] Initialized to watch directory: '%s'.",
            input_dir);

    // Prepare signal handlers for teardown
    sst::signals::register_handler(SIGTERM, queue);
    sst::signals::register_handler(SIGINT, queue);

    // Start main loop
    os_log(sst::g_logger, "[sstd] Dispatching… Press CTRL-C to stop.");
    ::CFRunLoopRun();

    // Stop & Invalidate FSEventStream
    stream_ctx.stop();

    const bool graceful_close{::close(dir_fd) != -1};
    if (!graceful_close) [[unlikely]] {
        os_log_error(sst::g_logger,
                "[sstd] Failed to close directory: '%s'\n.", input_dir);
    }

    // Shutdown
    const bool graceful_shutdown{processor.shutdown()};
    if (!graceful_shutdown) [[unlikely]] {
        os_log_error(sst::g_logger,
                "[sstd] Processor failed to shut down "
                "gracefully.\n");
    }

    return graceful_close && graceful_shutdown ? EX_OK : EX_OSERR;
}
