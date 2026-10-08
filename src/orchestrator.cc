#include "orchestrator.hh"

#include <CoreServices/CoreServices.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>

#include <cstddef>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#include "filter.hh"
#include "processor.hh"
#include "stream_context.hh"

static inline constexpr unsigned kFSEventStreamFlags{
        ::kFSEventStreamEventFlagItemIsFile |
        ::kFSEventStreamEventFlagItemCreated |
        ::kFSEventStreamEventFlagItemRenamed};

static void inspect(int dir_fd, const char* filename,
        std::vector<std::string>& files, unsigned max_retries) noexcept;

bool sst::orchestrator::cleanup(const processor& processor, const int dir_fd,
        std::vector<std::string>& buffer, const unsigned max_retries) noexcept
{
    const int dir_fd_dup{::dup(dir_fd)};
    if (dir_fd_dup < 0) {
        std::fprintf(stderr,
                "[sstd:cleanup] Failed to duplicate file "
                "descriptor.\n");
        return false;
    }

    ::DIR* dir_stream{nullptr};
    for (unsigned i{0U}; i < max_retries; ++i) {
        if ((dir_stream = ::fdopendir(dir_fd_dup))) [[likely]] {
            break;
        }
        if (errno != EINTR) [[unlikely]] {
            break;
        }
    }
    if (!dir_stream) {
        std::fprintf(stderr,
                "[sstd:cleanup] Failed to open directory stream for "
                "file descriptor: %d.\n",
                dir_fd_dup);
        ::close(dir_fd_dup);

        return false;
    }

    ::dirent* entry{nullptr};
    while ((entry = ::readdir(dir_stream))) {
        const char* filename{entry->d_name};

        if (filename[0] == '.' || entry->d_type != DT_REG) [[unlikely]] {
            continue;
        }

        inspect(dir_fd_dup, filename, buffer, max_retries);
    }

    if (::closedir(dir_stream) == -1) [[unlikely]] {
        std::fprintf(
                stderr, "[sstd:cleanup] Failed to close directory stream.\n");
        return false;
    }

    return processor.send_filenames(buffer);
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
            constexpr unsigned max_retries{5U};
            inspect(dir_fd, slash + 1, buffer, max_retries);
        }
    }

    (void) processor.send_filenames(buffer);
}

static void inspect(const int dir_fd, const char* filename,
        std::vector<std::string>& files, const unsigned max_retries) noexcept
{
    const int fd{::openat(dir_fd, filename, sst::kIOFlags)};
    if (fd < 0) [[unlikely]] {
        return;
    }

    if (sst::filter::is_image(fd, max_retries)) [[likely]] {
        files.emplace_back(filename);
    }

    if (::close(fd) != 0) [[unlikely]] {
        std::fprintf(stderr, "[sstd:cleanup] Failed to close file: %s.\n",
                filename);
    }
}
