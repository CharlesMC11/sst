#include "processor.hh"

#include <spawn.h>

#include <format>
#include <iostream>

extern char** environ;

namespace sst {

    processor::processor(const image::metadata& metadata) : metadata_{metadata}
    {
        if (pipe(fds_) != 0) [[unlikely]] {
            std::cerr << "Couldn’t open a pipe!\n";
            return;
        }

        posix_spawn_file_actions_t actions;
        posix_spawn_file_actions_init(&actions);

        posix_spawn_file_actions_adddup2(&actions, fds_[0], STDIN_FILENO);
        posix_spawn_file_actions_addclose(&actions, fds_[1]);

        const char regex[]{
                R"(Filename;s/(?:^.+?)(\d{4})\D(\d{2})\D(\d{2})\D+?(\d{2})\D(\d{2})\D(\d{2})(?:.+$))"};

        formatted_args_ = {std::format("-Model={}", metadata_.hardware),
                std::format("-Software={}", metadata_.software),
                std::format("-OffsetTime*={}", metadata_.timezone),
                std::format("-AllDates<${{{}/$1:$2:$3 $4:$5:$6{}/}}", regex,
                        metadata_.timezone),
                std::format("-Filename<${{{}/$1$2$3_$4$5$6/}}%-c%lE", regex),
                std::format("{}/charlesmc.args", metadata_.arg_files_dir),
                std::format("{}/screenshot.args", metadata_.arg_files_dir)};

        const char* args[]{"exiftool", "-stay_open", "True", "-@", "-",
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

        if (posix_spawn(&pid_, "/opt/homebrew/bin/exiftool", &actions, nullptr,
                    const_cast<char**>(args), environ) != 0) [[unlikely]] {
            std::cerr << "[sstd:processor] Couldn’t spawn ExifTool!\n";

            close(fds_[0]);
            close(fds_[1]);
            fds_[0] = fds_[1] = pid_ = -1;
            posix_spawn_file_actions_destroy(&actions);

            return;
        }

        close(fds_[0]);
        posix_spawn_file_actions_destroy(&actions);

        std::cout << "[sstd:processor] ExifTool is now running…" << std::endl;
    }

    processor::~processor()
    {
        if (pid_ == -1) [[unlikely]] {
            return;
        }

        send("-stay_open\nFalse\n-execute\n");

        if (fds_[1] >= 0) [[likely]] {
            close(fds_[1]);
        }

        waitpid(pid_, nullptr, 0);
    }

} // namespace sst
