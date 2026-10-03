#include "processor.hh"

#include <fcntl.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>

#include <cstddef>
#include <format>
#include <iostream>
#include <string_view>

// FIXME: Apparently this is brittle even though it works
extern char** environ;

constexpr char regex[]{
        R"(Filename;s/^\D+(\d{4})-(\d{2})-(\d{2}) at (\d{2})\.(\d{2})\.(\d{2})(?: \((\d)\))?.+$)"};

namespace {

    struct posix_spawn_file_actions final {
        ::posix_spawn_file_actions_t data;

        posix_spawn_file_actions() { ::posix_spawn_file_actions_init(&data); };
        ~posix_spawn_file_actions()
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

} // namespace

namespace sst {

    processor::processor(
            const char* exiftool_path, const image::metadata& metadata)
        : metadata_{metadata}
    {
        if (!pipe_.is_valid()) [[unlikely]] {
            return;
        }

        ::posix_spawn_file_actions actions;
        ::posix_spawn_file_actions_adddup2(
                &actions.data, pipe_.fds[0], STDIN_FILENO);
        ::posix_spawn_file_actions_addclose(&actions.data, pipe_.fds[1]);

        formatted_args_ = {std::format("-Model={}", metadata_.hardware),
                std::format("-Software={}", metadata_.software),
                std::format("-OffsetTime*={}", metadata_.timezone),
                std::format("-AllDates<${{{}/$1:$2:$3 $4:$5:$6{}/}}", regex,
                        metadata_.timezone),
                std::format("-Filename<${{{}/$1$2$3-$4$5$6/}}%-c%lE", regex),
                std::format("{}/charlesmc.args", metadata_.arg_files_dir),
                std::format("{}/screenshot.args", metadata_.arg_files_dir)};

        const char* args[]{exiftool_path, "-stay_open", "True", "-@", "-",
                "-common_args", "-struct", "-preserve", "-verbose", "-o",
                metadata_.output_dir.c_str(),
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
                    const_cast<char**>(args), environ) != 0) [[unlikely]] {
            std::cerr << "[sstd:processor] Failed to spawn ExifTool.\n";

            pid_ = -1;

            return;
        }

        pipe_.close(0UZ);

        std::cout << "[sstd:processor] ExifTool is now running…" << std::endl;
    }

    processor::~processor()
    {
        if (pid_ == -1) [[unlikely]] {
            return;
        }

        send("-stay_open\nFalse\n-execute\n");
        pipe_.close(1UZ);

        ::waitpid(pid_, nullptr, 0);
    }

    void processor::send(std::string_view args) const noexcept
    {
        std::cout << "[sstd:processor] Received args: " << args << std::endl;

        const std::string formatted_arg{std::format("{}\n-execute\n", args)};

        // FIXME: Check result && account for partial writes
        write(pipe_.fds[1], formatted_arg.data(), formatted_arg.size());
    }

    processor::pipe::pipe() noexcept
    {
        if (::pipe(fds) != 0) [[unlikely]] {
            std::cerr << "[sstd:processor] Failed to open a pipe.\n";
            return;
        }
    }

    processor::pipe::~pipe() noexcept
    {
        close(0UZ);
        close(1UZ);
    }

    void processor::pipe::close(std::size_t idx) noexcept
    {
        if (fds[idx] == -1) [[unlikely]] {
            return;
        }

        if (::close(fds[idx]) != 0) [[unlikely]] {
            std::cerr << "Could not close file descriptor: " << fds[idx]
                      << ".\n";
        }

        fds[idx] = -1;
    }

} // namespace sst
