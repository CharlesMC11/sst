#include "processor.hh"

#import <Foundation/Foundation.h>
#include <crt_externs.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>

#include <cerrno>
#include <cstddef>
#include <cstdio>
#include <format>
#include <print>
#include <string_view>
#include <system_error>
#include <vector>

static inline constexpr char kFilenameRegex[]{
        R"(Filename;s/^\D+(\d{4})-(\d{2})-(\d{2}) at (\d{2})\.(\d{2})\.(\d{2})(?: \((\d)\))?.+$)"};

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

    [[nodiscard]] std::string get_timezone();
    [[nodiscard]] std::string get_os_version();

} // unnamed namespace

namespace sst {

    processor::processor(const char* const exiftool_path,
            const image::metadata& metadata, const unsigned max_retries)
        : input_dir_{metadata.input_dir}, max_retries_{max_retries}
    {
        posix_spawn_file_actions actions;
        ::posix_spawn_file_actions_adddup2(
                &actions.data, pipe_.fds[0UZ], STDIN_FILENO);
        ::posix_spawn_file_actions_addclose(&actions.data, pipe_.fds[1UZ]);

        const std::string timezone{get_timezone()};

        const std::string formatted_args[]{
                std::format("-Model={}", metadata.hw_model),
                std::format("-Software={}", get_os_version()),
                std::format("-OffsetTime*={}", timezone),
                std::format("-AllDates<${{{}/$1:$2:$3 $4:$5:$6{}/}}",
                        kFilenameRegex, timezone),
                std::format(
                        R"(-Filename<${{{}/my $N = $7 ? sprintf("%02d", $7) : "";"$1$2$3-$4$5$6{}_$N"/e}}%-c%lE)",
                        kFilenameRegex, timezone),
                std::format("{}/charlesmc.args", metadata.arg_files_dir),
                std::format("{}/screenshot.args", metadata.arg_files_dir)};

        const char* const args[]{exiftool_path, "-stay_open", "True", "-@",
                "-", "-common_args", "-struct", "-preserve", "-verbose", "-o",
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

        pipe_.close(0UZ);
        std::println("[sstd:processor] ExifTool is now running…");
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

    // TODO: Could probably clean this up later
    [[nodiscard]] bool processor::send_filenames(
            const std::vector<std::string>& filenames) const
    {
        if (filenames.empty()) {
            return true;
        }

        std::size_t length{
                10UZ + (std::strlen(input_dir_) + 1UZ) * filenames.size()};
        for (const auto& filename: filenames) {
            length += filename.length();
        }

        std::string buffer;
        buffer.reserve(length);

        for (const auto& filename: filenames) {
            buffer.append(input_dir_);
            buffer.push_back('/');
            buffer.append(filename);
            buffer.push_back('\n');
        }
        buffer.append("-execute\n");

        return send_payload(buffer);
    }

    [[nodiscard]] bool processor::shutdown() noexcept
    {
        if (pid_ == -1) [[unlikely]] {
            return true;
        }

        const bool is_exiftool_closed{
                send_payload("-stay_open\nFalse\n-execute\n")};
        pipe_.close(1UZ);

        const bool is_reaped{
                ::waitpid(pid_, nullptr, 0) != -1 && is_exiftool_closed};
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

    [[nodiscard]] bool processor::send_payload(
            const std::string_view args) const noexcept
    {
        const std::size_t length{args.length()};
        std::size_t total_written{0UZ};
        unsigned retries{0U};
        while (total_written < length && retries <= max_retries_) {
            const std::ptrdiff_t bytes_written{::write(pipe_.fds[1UZ],
                    args.data() + total_written, length - total_written)};

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

} // namespace sst

namespace {
    [[nodiscard]] std::string get_timezone()
    {
        const NSTimeZone* local_timezone{[NSTimeZone localTimeZone]};
        const long offset_seconds{[local_timezone secondsFromGMT]};
        const long offset_hours{offset_seconds / 3600L};

        return std::format("{:03d}00", offset_hours);
    }

    [[nodiscard]] std::string get_os_version()
    {
        const NSOperatingSystemVersion os_ver{
                [NSProcessInfo processInfo].operatingSystemVersion};

        return std::format("{}.{}.{}", os_ver.majorVersion,
                os_ver.minorVersion, os_ver.patchVersion);
    }

} // unnamed namespace
