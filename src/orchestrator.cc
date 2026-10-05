#include <CoreServices/CoreServices.h>
#include <fcntl.h>
#include <unistd.h>

#include <cstddef>
#include <cstring>
#include <string>
#include <vector>

#include "orchestrator.hh"
#include "processor.hh"
#include "signatures.hh"
#include "sorter.hh"
#include "stream_context.hh"

extern "C" const int kIOFlags; // Declared in `fs_monitor.mm`

void sst::orchestrator::scan_directory(
        [[maybe_unused]] ::ConstFSEventStreamRef stream_ref,
        void* client_callback_info, std::size_t num_events, void* event_paths,
        const ::FSEventStreamEventFlags event_flags[],
        [[maybe_unused]] const ::FSEventStreamEventId event_ids[])
{
    const auto monitor{
            static_cast<sst::stream_context*>(client_callback_info)};
    const sst::processor& processor{monitor->processor()};
    const int dir_fd{monitor->dir_fd()};

    std::vector<std::string>& buffer{monitor->buffer()};
    buffer.clear();

    std::size_t count{0UZ};
    auto paths{static_cast<const char* const*>(event_paths)};
    for (std::size_t i{0UZ}; i < num_events; ++i) {

        const char* const path{paths[i]};
        const std::size_t path_len{std::strlen(path)};
        if (path_len == 0UZ) [[unlikely]] {
            continue;
        }

        // The watched directory is guaranteed to have no subdirectories
        const char* const slash{std::strrchr(path, '/')};
        if (slash == nullptr || slash[1] == '\0' || slash[1] == '.')
                [[unlikely]] {
            continue;
        }

        const ::FSEventStreamEventFlags curr_flags{event_flags[i]};

        const bool is_file{
                (curr_flags & ::kFSEventStreamEventFlagItemIsFile) != 0};
        const bool is_relevant{
                (curr_flags &
                        (::kFSEventStreamEventFlagItemCreated |
                                ::kFSEventStreamEventFlagItemRenamed)) != 0};

        if (is_relevant && is_file) [[likely]] {
            const int fd{::openat(dir_fd, slash + 1, kIOFlags)};
            if (fd < 0) [[unlikely]] {
                continue;
            }

            if (sst::orchestrator::is_image(fd)) [[likely]] {
                buffer.emplace_back(path);
                ++count;
            }

            if (::close(fd) != 0) {
                // TODO: Some error message
            }
        }
    }

    if (count > 0UZ) [[likely]] {
        sst::sorter::natural_sort(buffer);
        for (const auto& file_path: buffer) {
            processor.send(file_path);
        }
    }
}
