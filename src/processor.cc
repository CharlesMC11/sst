#include "processor.hh"

#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>

#include <cerrno>
#include <cstddef>
#include <format>
#include <iostream>
#include <string_view>
#include <system_error>
#include <vector>

// FIXME: Apparently this is brittle even though it works
extern char** environ;

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

} // anonymous namespace

namespace sst {

    processor::processor(const char* const exiftool_path,
            const image::metadata& metadata, const unsigned max_retries)
        : input_dir_{metadata.input_dir}, max_retries_{max_retries}
    {
        ::posix_spawn_file_actions actions;
        ::posix_spawn_file_actions_adddup2(
                &actions.data, pipe_.fds[0], STDIN_FILENO);
        ::posix_spawn_file_actions_addclose(&actions.data, pipe_.fds[1]);

        formatted_args_ = {std::format("-Model={}", metadata.hw_model),
                std::format("-Software={}", metadata.os_ver),
                std::format("-OffsetTime*={}", metadata.timezone),
                std::format("-AllDates<${{{}/$1:$2:$3 $4:$5:$6{}/}}",
                        kFilenameRegex, metadata.timezone),
                std::format("-Filename<${{{}/$1$2$3-$4$5$6/}}%-c%lE",
                        kFilenameRegex),
                std::format("{}/charlesmc.args", metadata.arg_files_dir),
                std::format("{}/screenshot.args", metadata.arg_files_dir)};

        const char* const args[]{exiftool_path, "-stay_open", "True", "-@",
                "-", "-common_args", "-struct", "-preserve", "-verbose", "-o",
                metadata.output_dir,
                formatted_args_[0].c_str(), // hardware
                formatted_args_[1].c_str(), // software
                formatted_args_[2].c_str(), // timezone
                formatted_args_[3].c_str(), // new datetime pattern
                formatted_args_[4].c_str(), // new filename pattern
                "-@",
                formatted_args_[5].c_str(), // charlesmc.args
                "-@",
                formatted_args_[6].c_str(), // screenshots.args
                nullptr};

        if (::posix_spawn(&pid_, exiftool_path, &actions.data, nullptr,
                    const_cast<char**>(args), ::environ) != 0) [[unlikely]] {
            throw std::system_error{errno, std::generic_category(),
                    "[sstd:processor] Failed to spawn ExifTool."};
        }

        pipe_.close(0UZ);
        std::println("[sstd:processor] ExifTool is now running…");
    }

    processor::~processor()
    {
        if (pid_ == -1) [[unlikely]] {
            return;
        }

        // TODO: Grab result here later
        send("-stay_open\nFalse\n-execute\n");
        pipe_.close(1UZ);

        ::waitpid(pid_, nullptr, 0);
    }

    // TODO: Could probably clean this up later
    [[nodiscard]] bool processor::send_filenames(
            const std::vector<std::string>& filenames) const
    {
        std::string formatted_args;
        formatted_args.reserve(PATH_MAX);

        for (const auto& filename: filenames) {
            formatted_args += std::format("{}/{} ", input_dir_, filename);
        }

        return send(formatted_args);
    }

    processor::pipe::pipe()
    {
        if (::pipe(fds) != 0) [[unlikely]] {
            throw std::system_error{errno, std::generic_category(),
                    "[sstd:processor] Failed to create a pipe."};
        }
    }

    processor::pipe::~pipe()
    {
        close(0UZ);
        close(1UZ);
    }

    void processor::pipe::close(const std::size_t idx)
    {
        if (fds[idx] == -1) [[unlikely]] {
            return;
        }

        if (::close(fds[idx]) != 0) [[unlikely]] {
            std::println(std::cerr, "Could not close file descriptor: {}.",
                    fds[idx]);
        }

        fds[idx] = -1;
    }

    [[nodiscard]] bool processor::send(std::string_view args) const
    {
        const std::string formatted_args{std::format("{}\n-execute\n", args)};

        // NOTE: It’s so unlikely to fill up 16 KB, maybe we should drop this
        // altogether?

        const std::size_t length{formatted_args.length()};
        std::size_t total_written{0Z};
        unsigned reattempts{0U};
        while (total_written < length && reattempts <= max_retries_)
                [[unlikely]] {
            const std::ptrdiff_t written{::write(pipe_.fds[1Z],
                    formatted_args.data() + total_written,
                    length - total_written)};

            written > 0Z ? total_written += static_cast<std::size_t>(written)
                         : ++reattempts;
        }
        return total_written == length;
    }

} // namespace sst
