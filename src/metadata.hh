#pragma once

#include <chrono>
#include <format>
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
              os_ver{get_os_version()}
        {
            // TODO: Actually get the timezone
            using std::string_literals::operator""s;
            timezone = "-07:00"s;
        }

    private:
        static std::string get_os_version();
    };

} // namespace sst::image
