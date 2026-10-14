#include "orchestrator.hh"

#include <CoreServices/CoreServices.h>
#include <dirent.h>
#include <os/log.h>
#include <unistd.h>

#include <cstring>
#include <stdexcept>
#include <string>

#include "filter.hh"
#include "processor.hh"

namespace sst {

    extern const ::os_log_t g_logger;

    static inline constexpr FSEventStreamEventFlags kFSEventStreamFlags{
            ::kFSEventStreamEventFlagItemIsFile |
            ::kFSEventStreamEventFlagItemCreated |
            ::kFSEventStreamEventFlagItemRenamed};

    void orchestrator::run([[maybe_unused]] ::ConstFSEventStreamRef stream_ref,
            void* client_callback_info, const std::size_t num_events,
            void* const event_paths,
            const ::FSEventStreamEventFlags event_flags[],
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
            if (path[0UZ] == '\0') [[unlikely]] {
                continue;
            }

            // The watched directory is guaranteed to have no subdirectories
            const char* const slash{std::strrchr(path, '/')};
            if (slash == nullptr || slash[1UZ] == '\0' || slash[1UZ] == '.')
                    [[unlikely]] {
                continue;
            }

            const char* const filename{slash + 1UZ};
            if ((event_flags[i] & kFSEventStreamFlags) != 0U) [[likely]] {
                orchestrator->inspect(filename, std::strlen(filename));
            }
        }

        (void) orchestrator->processor().send_to_exiftool(buffer);
    }

    orchestrator::orchestrator(sst::processor& processor,
            std::string_view input_dir_path, const int input_dir_fd,
            std::string& buffer, const unsigned max_retries)
        : processor_{processor}, input_dir_path_{input_dir_path},
          input_dir_fd_{input_dir_fd}, max_retries_{max_retries},
          buffer_{buffer}
    {
        if (!processor.is_running() || input_dir_fd == -1) [[unlikely]] {
            throw std::runtime_error{
                    "[sstd:orchestrator] Failed to instantiate orchestrator."};
        }
    }

    bool orchestrator::cleanup() const noexcept
    {
        const int dir_fd_dup{::dup(input_dir_fd_)};
        if (dir_fd_dup < 0) {
            os_log_error(g_logger,
                    "[sstd:cleanup] Failed to duplicate file "
                    "descriptor.\n");
            return false;
        }

        ::DIR* dir_stream{nullptr};
        for (unsigned i{0U}; i < max_retries_; ++i) {
            dir_stream = ::fdopendir(dir_fd_dup);
            if (dir_stream) [[likely]] {
                break;
            }
            if (errno != EINTR) [[unlikely]] {
                break;
            }
        }
        if (!dir_stream) {
            os_log_error(g_logger,
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

            if (filename[0UZ] == '.' || entry->d_type != DT_REG) [[unlikely]] {
                continue;
            }

            inspect(filename, entry->d_namlen);
        }

        if (::closedir(dir_stream) == -1) [[unlikely]] {
            os_log_error(g_logger,
                    "[sstd:cleanup] Failed to close directory stream.\n");
            return false;
        }

        return processor_.send_to_exiftool(buffer_);
    }

    void orchestrator::inspect(
            const char* filename, const std::size_t length) const noexcept
    {
        const int fd{::openat(input_dir_fd_, filename, kIOFlags)};
        if (fd < 0) [[unlikely]] {
            return;
        }

        if (filter::is_image(fd, max_retries_)) [[likely]] {
            buffer_.append(filename, length).push_back('\n');
        }

        if (::close(fd) != 0) [[unlikely]] {
            os_log_error(g_logger,
                    "[sstd:cleanup] Failed to close file: %s.\n", filename);
        }
    }

} // namespace sst
