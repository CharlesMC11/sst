#pragma once

namespace sst {

    struct exiftool_args final {
        const int input_dir_fd;

        exiftool_args(int input_dir_fd, const char* exiftool_path,
                const char* output_dir, const char* arg_files_dir);

        [[nodiscard]] auto path() const noexcept -> const char*
        {
            return argv_[0U];
        }

        [[nodiscard]] auto argv() const noexcept -> const char* const*
        {
            return argv_;
        }

    private:
        const char* argv_[13UZ];
    };

} // namespace sst
