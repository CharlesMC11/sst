#include "processor.hh"

#include <crt_externs.h>
#include <os/log.h>
#include <spawn.h>
#include <sys/uio.h>
#include <sys/wait.h>
#include <unistd.h>

#include <cerrno>
#include <cstddef>
#include <string_view>
#include <system_error>

namespace {

    class posix_spawn_file_actions final {
    public:
        ::posix_spawn_file_actions_t data{nullptr};

        posix_spawn_file_actions() { ::posix_spawn_file_actions_init(&data); };
        ~posix_spawn_file_actions() noexcept
        {
            ::posix_spawn_file_actions_destroy(&data);
        };

        posix_spawn_file_actions(const posix_spawn_file_actions&) = delete;
        posix_spawn_file_actions(posix_spawn_file_actions&&) = delete;

        auto operator=(const posix_spawn_file_actions&)
                -> posix_spawn_file_actions& = delete;
        auto operator=(posix_spawn_file_actions&&)
                -> posix_spawn_file_actions& = delete;
    };

} // unnamed namespace

namespace sst {

    extern const ::os_log_t g_logger;

    processor::processor(const exiftool_args& args, const unsigned max_retries)
        : max_retries_{max_retries}
    {
        posix_spawn_file_actions actions;
        ::posix_spawn_file_actions_adddup2(
                &actions.data, stdout_pipe_.fds[0UZ], STDIN_FILENO);
        ::posix_spawn_file_actions_addclose(
                &actions.data, stdout_pipe_.fds[1UZ]);

        // ::posix_spawn_file_actions_adddup2(
        // &actions.data, stdin_pipe_.fds[1UZ], STDOUT_FILENO);
        // ::posix_spawn_file_actions_addclose(
        // &actions.data, stdin_pipe_.fds[0UZ]);

        ::posix_spawn_file_actions_addfchdir(&actions.data, args.input_dir_fd);

        if (::posix_spawn(&pid_, args.executable_path(), &actions.data,
                    nullptr, const_cast<char**>(args.argv()),
                    *::_NSGetEnviron()) != 0) [[unlikely]] {
            throw std::system_error{errno, std::generic_category(),
                    "[sstd:processor] Failed to spawn ExifTool."};
        }
        stdout_pipe_.close(0UZ);

        os_log_info(g_logger, "[sstd:processor] ExifTool is now running.");
    }

    processor::~processor() noexcept
    {
        if (pid_ == -1) [[likely]] {
            return;
        }

        if (!shutdown()) {
            os_log_error(g_logger,
                    "[sstd:processor] Did not shut down gracefully!\n");
        }
    }

    [[nodiscard]] bool processor::send_to_exiftool(
            std::string_view file_paths) const
    {
        if (file_paths.empty()) {
            return true;
        }

        const ::iovec cmd[]{{.iov_base = const_cast<char*>(file_paths.data()),
                                    .iov_len = file_paths.length()},
                kExecuteCmd};

        return send_payload(cmd);
    }

    [[nodiscard]] bool processor::shutdown() noexcept
    {
        if (pid_ == -1) [[unlikely]] {
            return true;
        }

        const bool has_exiftool_closed{send_payload(kShutdownCmd)};
        stdout_pipe_.close(1UZ);

        const bool is_reaped{
                ::waitpid(pid_, nullptr, 0) != -1 && has_exiftool_closed};
        pid_ = -1;

        return is_reaped;
    }

    processor::pipe::pipe()
    {
        if (::pipe(fds) != 0) [[unlikely]] {
            throw std::system_error{errno, std::generic_category(),
                    "[sstd:processor] Failed to create a pipe.\n"};
        }
    }

    processor::pipe::~pipe() noexcept
    {
        close(0UZ);
        close(1UZ);
    }

    void processor::pipe::close(const std::size_t idx) noexcept
    {
        if (fds[idx] == -1) [[unlikely]] {
            return;
        }

        if (::close(fds[idx]) != 0) [[unlikely]] {
            os_log_error(g_logger, "Could not close file descriptor: %d.\n",
                    fds[idx]);
        }

        fds[idx] = -1;
    }

    [[nodiscard]] bool processor::send_payload(
            const ::iovec vec[]) const noexcept
    {
        const std::size_t first_len{vec[0UZ].iov_len};
        const std::size_t total_len{first_len + kExecuteCmd.iov_len};
        std::size_t total_written{0UZ};

        unsigned retries{0U};
        while (total_written < total_len && retries <= max_retries_) {
            const std::ptrdiff_t bytes_written{
                    ::writev(stdout_pipe_.fds[1UZ], vec, 2UZ)};

            if (bytes_written <= 0Z) [[unlikely]] {
                if (errno == EINTR) {
                    continue;
                }
                if (errno == EPIPE) {
                    os_log_error(g_logger,
                            "[sstd:processor] Pipe broken (ExifTool "
                            "Terminated)\n");
                    break;
                }
                ++retries;
                continue;
            }
            total_written += static_cast<std::size_t>(bytes_written);
            retries = 0U;

            // FIXME: Partial writes
        }

        return total_written == total_len;
    }

} // namespace sst
