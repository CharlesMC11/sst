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

static inline constexpr unsigned kFSEventStreamFlags{
        ::kFSEventStreamEventFlagItemIsFile |
        ::kFSEventStreamEventFlagItemCreated |
        ::kFSEventStreamEventFlagItemRenamed};

static void inspect(
        int dir_fd, const char* filename, std::vector<std::string>& files);

void sst::orchestrator::cleanup(int dir_fd, const processor& processor,
        std::vector<std::string>& files)
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

    dirent* entry{nullptr};
    while ((entry = ::readdir(dir_stream))) {
        const char* filename{entry->d_name};

        if (filename[0] == '.' || entry->d_type != DT_REG) [[unlikely]] {
            continue;
        }

        inspect(dir_fd, filename, files);
    }

    if (::fdclosedir(dir_stream) == -1) [[unlikely]] {
        std::cerr
                << "[sstd:stream_context] Failed to close directory stream.\n";
        return;
    }

    sst::sorter::natural_sort(files);
    std::ranges::for_each(files.begin(), files.end(),
            [&processor](const auto& f) -> void { processor.send(f); });
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

    const auto paths{static_cast<const char* const*>(event_paths)};
    for (std::size_t i{0UZ}; i < num_events; ++i) {

        const char* const path{paths[i]};
        // Is there even a possibility of FSEvents sending an empty string?
        if (path[0] == '\0') [[unlikely]] {
            continue;
        }

        // The watched directory is guaranteed to have no subdirectories
        const char* const slash{std::strrchr(path, '/')};
        if (slash == nullptr || slash[1] == '\0' || slash[1] == '.')
                [[unlikely]] {
            continue;
        }

        if ((event_flags[i] & kFSEventStreamFlags) != 0) [[likely]] {
            inspect(dir_fd, slash + 1, buffer);
        }
    }

    if (!buffer.empty()) [[likely]] {
        sst::sorter::natural_sort(buffer);
        std::ranges::for_each(buffer.begin(), buffer.end(),
                [&processor](const auto& f) -> void { processor.send(f); });
    }
}

static void inspect(const int dir_fd, const char* filename,
        std::vector<std::string>& files)
{
    const int fd{::openat(dir_fd, filename, kIOFlags)};
    if (fd < 0) [[unlikely]] {
        return;
    }

    if (sst::filter::is_image(fd)) [[likely]] {
        files.emplace_back(filename);
    }

    if (::close(fd) != 0) [[unlikely]] {
        // TODO: Some error message
    }
}
