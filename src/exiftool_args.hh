#pragma once

namespace sst {

    class exiftool_args final {
    public:
        const int input_dir_fd;

        explicit exiftool_args(int input_dir_fd, const char* exiftool_path,
                const char* output_dir, const char* arg_files_dir);

        ~exiftool_args() = default;

        exiftool_args(const exiftool_args&) = delete;
        exiftool_args(exiftool_args&&) = delete;

        auto operator=(const exiftool_args&) -> exiftool_args& = delete;
        auto operator=(exiftool_args&&) -> exiftool_args& = delete;

        [[nodiscard]] auto executable_path() const noexcept -> const char*
        {
            return argv_[0UZ];
        }

        [[nodiscard]] auto argv() const noexcept -> const char* const*
        {
            return argv_;
        }

    private:
        const char* argv_[13UZ];
    };

} // namespace sst
