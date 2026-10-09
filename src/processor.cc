#include "processor.hh"

#include <crt_externs.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>

#include <cerrno>
#include <cstddef>
#include <cstdio>
#include <format>
#include <print>
#include <string>
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

    processor::processor(const char* const exiftool_path,
            const image::metadata& metadata, const unsigned max_retries,
            std::size_t init_buffer_size)
        : max_retries_{max_retries}
    {
        posix_spawn_file_actions actions;
        ::posix_spawn_file_actions_adddup2(
                &actions.data, outbound_pipe_.fds[0UZ], STDIN_FILENO);
        ::posix_spawn_file_actions_addclose(
                &actions.data, outbound_pipe_.fds[1UZ]);

        ::posix_spawn_file_actions_adddup2(
                &actions.data, inbound_pipe_.fds[1UZ], STDOUT_FILENO);
        ::posix_spawn_file_actions_addclose(
                &actions.data, inbound_pipe_.fds[0UZ]);

        const char* const timezone{sst::image::metadata::timezone()};

        const std::string formatted_args[]{
                std::format("-Model={}", metadata.hw_model),
                std::format(
                        "-Software={}", sst::image::metadata::os_version()),
                std::format("-OffsetTime*={}", timezone),
                std::format("-AllDates<${{{}}}",
                        sst::image::metadata::kRegexReplacePrefix, timezone),
                std::format(
                        R"(-Filename<${{{}/my $N = defined($7) ? sprintf("_%02d", $7) : ""; "$1$2$3-$4$5$6{}$N"/e}}%-c%lE)",
                        sst::image::metadata::kRegexReplacePrefix, timezone),
                std::format("{}/charlesmc.args", metadata.arg_files_dir),
                std::format("{}/screenshot.args", metadata.arg_files_dir)};

        const char* const args[]{exiftool_path, "-stay_open", "True", "-@",
                "-", "-common_args", "-struct", "-preserve", "-o",
                metadata.output_dir,
                formatted_args[0UZ].c_str(), // hardware
                formatted_args[1UZ].c_str(), // software
                formatted_args[2UZ].c_str(), // timezone
                formatted_args[3UZ].c_str(), // new datetime pattern
                formatted_args[4UZ].c_str(), // new filename pattern
                "-@",
                formatted_args[5UZ].c_str(), // charlesmc.args
                "-@",
                formatted_args[6UZ].c_str(), // screenshots.args
                nullptr};

        if (::posix_spawn(&pid_, exiftool_path, &actions.data, nullptr,
                    const_cast<char**>(args), *::_NSGetEnviron()) != 0)
                [[unlikely]] {
            throw std::system_error{errno, std::generic_category(),
                    "[sstd:processor] Failed to spawn ExifTool."};
        }

        outbound_pipe_.close(0UZ);
        inbound_pipe_.close(1UZ);

        buffer_.reserve(init_buffer_size);

        //        if (!(send_payload("-execute\n") && wait())) {
        //            throw std::runtime_error{"[sstd:processor] Exiftool
        //            failed to "
        //                                     "send a ready signal."};
        //        }

        std::println("[sstd:processor] ExifTool is now running.");
    }

    processor::~processor() noexcept
    {
        if (pid_ == -1) [[likely]] {
            return;
        }

        if (!shutdown()) {
            std::fprintf(stderr,
                    "[sstd:processor] Did not shut down gracefully!\n");
        }
    }

    [[nodiscard]] bool processor::send_to_exiftool(std::string_view file_paths)
    {
        if (file_paths.empty()) {
            return true;
        }

        buffer_.clear();
        buffer_.append(file_paths);
        buffer_.append("-execute\n");

        return send_payload();
    }

    [[nodiscard]] bool processor::shutdown() noexcept
    {
        if (pid_ == -1) [[unlikely]] {
            return true;
        }

        buffer_.clear();
        buffer_.append("-stay_open\nFalse\n-execute\n");
        const bool has_exiftool_closed{send_payload()};

        outbound_pipe_.close(1UZ);
        inbound_pipe_.close(0UZ);

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
            std::fprintf(stderr, "Could not close file descriptor: %d.\n",
                    fds[idx]);
        }

        fds[idx] = -1;
    }

    [[nodiscard]] bool processor::send_payload() const noexcept
    {
        const std::size_t length{buffer_.length()};
        std::size_t total_written{0UZ};
        unsigned retries{0U};
        while (total_written < length && retries <= max_retries_) {
            const std::ptrdiff_t bytes_written{::write(outbound_pipe_.fds[1UZ],
                    buffer_.data() + total_written, length - total_written)};

            if (bytes_written <= 0Z) [[unlikely]] {
                if (errno == EINTR) {
                    continue;
                }
                if (errno == EPIPE) {
                    std::fprintf(stderr,
                            "[sstd:processor] Pipe broken (ExifTool "
                            "Terminated)\n");
                    break;
                }
                ++retries;
                continue;
            }
            total_written += static_cast<std::size_t>(bytes_written);
            retries = 0U;
        }

        return total_written == length;
    }

    [[nodiscard]] bool processor::wait() const noexcept
    {
        std::string buffer;
        char ch;
        while (true) {
            const std::ptrdiff_t bytes_read{
                    ::read(inbound_pipe_.fds[0UZ], &ch, 1UZ)};
            if (bytes_read < 0Z) [[unlikely]] {
                if (errno == EINTR) {
                    continue;
                }
                return false;
            }
            if (bytes_read == 0UZ) {
                return false;
            }
            buffer.push_back(ch);
            if (buffer.length() >= 8UZ &&
                    buffer.rfind("{ready}") != std::string::npos) {
                return true;
            }
        }
    }

} // namespace sst
