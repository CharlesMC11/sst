#pragma once

#include <string>

namespace sst::image {

    struct metadata final {
        const char* const input_dir;
        const char* const output_dir;
        const char* const arg_files_dir;
        const char* const hw_model;
        std::string timezone;
        std::string os_ver;

        metadata(const char* const input_dir, const char* const output_dir,
                const char* const arg_files_dir, const char* const model)
            : input_dir{input_dir}, output_dir{output_dir},
              arg_files_dir{arg_files_dir}, hw_model{model},
              timezone{get_timezone()}, os_ver{get_os_version()}
        {
        }

    private:
        [[nodiscard]] static std::string get_timezone();
        [[nodiscard]] static std::string get_os_version();
    };

} // namespace sst::image
