#include "orchestrator.hh"

#include <CoreServices/CoreServices.h>
#include <dirent.h>
#include <unistd.h>

#include <cstdio>
#include <cstring>
#include <string>

#include "filter.hh"
#include "processor.hh"

static inline constexpr unsigned kFSEventStreamFlags{
        ::kFSEventStreamEventFlagItemIsFile |
        ::kFSEventStreamEventFlagItemCreated |
        ::kFSEventStreamEventFlagItemRenamed};

void sst::orchestrator::run(
        [[maybe_unused]] ::ConstFSEventStreamRef stream_ref,
        void* client_callback_info, const std::size_t num_events,
        void* const event_paths, const ::FSEventStreamEventFlags event_flags[],
        [[maybe_unused]] const ::FSEventStreamEventId event_ids[])
{
    const auto orchestrator{
            static_cast<sst::orchestrator*>(client_callback_info)};
    std::string& buffer{orchestrator->buffer()};
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
            orchestrator->inspect(slash + 1);
        }
    }

    (void) orchestrator->processor().send_to_exiftool(buffer);
}

sst::orchestrator::orchestrator(sst::processor& processor,
        const char* const input_dir_path, const int input_dir_fd,
        std::string& buffer, const unsigned max_retries)
    : processor_{processor}, input_dir_path_{input_dir_path},
      input_dir_fd_{input_dir_fd}, max_retries_{max_retries}, buffer_{buffer}
{
    if (!processor.is_running() || input_dir_path == nullptr ||
            input_dir_fd == -1) [[unlikely]] {
        throw std::runtime_error{
                "[sstd:orchestrator] Failed to instantiate orchestrator."};
    }
}

bool sst::orchestrator::cleanup() const noexcept
{
    const int dir_fd_dup{::dup(input_dir_fd_)};
    if (dir_fd_dup < 0) {
        std::fprintf(stderr,
                "[sstd:cleanup] Failed to duplicate file "
                "descriptor.\n");
        return false;
    }

    ::DIR* dir_stream{nullptr};
    for (unsigned i{0U}; i < max_retries_; ++i) {
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

    buffer_.clear();

    ::dirent* entry{nullptr};
    while ((entry = ::readdir(dir_stream))) {
        const char* filename{entry->d_name};

        if (filename[0] == '.' || entry->d_type != DT_REG) [[unlikely]] {
            continue;
        }

        inspect(filename);
    }

    if (::closedir(dir_stream) == -1) [[unlikely]] {
        std::fprintf(
                stderr, "[sstd:cleanup] Failed to close directory stream.\n");
        return false;
    }

    return processor_.send_to_exiftool(buffer_);
}

void sst::orchestrator::inspect(const char* filename) const noexcept
{
    const int fd{::openat(input_dir_fd_, filename, sst::kIOFlags)};
    if (fd < 0) [[unlikely]] {
        return;
    }

    if (sst::filter::is_image(fd, max_retries_)) [[likely]] {
        buffer_.append(input_dir_path_);
        buffer_.push_back('/');
        buffer_.append(filename);
        buffer_.push_back('\n');
    }

    if (::close(fd) != 0) [[unlikely]] {
        std::fprintf(stderr, "[sstd:cleanup] Failed to close file: %s.\n",
                filename);
    }
}
