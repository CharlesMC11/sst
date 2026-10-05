#include "orchestrator.hh"

#include <CoreServices/CoreServices.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>

#include <cstddef>
#include <cstring>
#include <iostream>
#include <print>
#include <string>
#include <vector>

#include "filter.hh"
#include "processor.hh"
#include "sorter.hh"
#include "stream_context.hh"

extern "C" const int kIOFlags{O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_CLOFORK};

void sst::orchestrator::cleanup(int dir_fd, const char* const dir_path,
        const processor& processor, std::vector<std::string>& files)
{
    if (dir_fd == -1) [[unlikely]] {
        std::println(std::cerr,
                "[sstd:stream_context] No open directory file descriptor or "
                "event stream. Cannot start file system stream_context.");
        return;
    }

    // FIXME:
    // const int dir_fd_{::dup(dir_fd)};
    // if (dir_fd_ < 0) {
    //     std::cerr << "[sstd:stream_context] Failed to duplicate file
    //     descriptor\n"; return;
    // }

    DIR* dir_stream{::fdopendir(dir_fd)};
    if (!dir_stream) [[unlikely]] {
        std::println(std::cerr,
                "[sstd:stream_context] Failed to open directory stream for "
                "file descriptor duplicate: {}",
                dir_fd);

        if (::close(dir_fd) != 0) {
            std::println(std::cerr,
                    "[sstd:stream_context] Failed to close directory file "
                    "descriptor");
        }
        return;
    }

    struct dirent* entry{nullptr};
    while ((entry = ::readdir(dir_stream))) {
        const char* filename{entry->d_name};

        if (filename[0] == '.' || entry->d_type != DT_REG) [[unlikely]] {
            continue;
        }

        const int fd{::openat(dir_fd, filename, kIOFlags)};
        if (fd < 0) [[unlikely]] {
            continue;
        }

        if (sst::filter::is_image(fd)) [[likely]] {
            const std::string full_path{
                    std::format("{}/{}", dir_path, filename)};
            files.push_back(full_path);
            std::println(
                    "[sstd:stream_context] Found entry: {}", entry->d_name);
        }

        if (::close(fd) != 0) {
            // TODO: Some error message
        }
    }

    if (::fdclosedir(dir_stream) == -1) [[unlikely]] {
        std::cerr
                << "[sstd:stream_context] Failed to close directory stream.\n";
        return;
    }
    dir_stream = nullptr;

    sst::sorter::natural_sort(files);
    for (const auto& file_path: files) {
        processor.send(file_path);
    }
}

void sst::orchestrator::orchestrate(
        [[maybe_unused]] ::ConstFSEventStreamRef stream_ref,
        void* client_callback_info, const std::size_t num_events,
        void* const event_paths, const ::FSEventStreamEventFlags event_flags[],
        [[maybe_unused]] const ::FSEventStreamEventId event_ids[])
{
    const auto monitor{
            static_cast<sst::stream_context*>(client_callback_info)};
    const sst::processor& processor{monitor->processor()};
    const int dir_fd{monitor->dir_fd()};

    std::vector<std::string>& buffer{monitor->buffer()};
    buffer.clear();

    std::size_t count{0UZ};
    const auto paths{static_cast<const char* const*>(event_paths)};
    for (std::size_t i{0UZ}; i < num_events; ++i) {

        const char* const path{paths[i]};
        // Is there even a possibility of FSEvents sending an empty string?
        // if (std::strlen(path) == 0UZ) [[unlikely]] {
        //     continue;
        // }

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

            if (sst::filter::is_image(fd)) [[likely]] {
                buffer.emplace_back(path);
                ++count;
            }

            if (::close(fd) != 0) [[unlikely]] {
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
