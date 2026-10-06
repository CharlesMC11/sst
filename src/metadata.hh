#pragma once

#include <chrono>
#include <format>
#include <string>
#include <string_view>

namespace sst::image {

    struct metadata final {
        const char* const input_dir;
        const char* const output_dir;
        const char* const arg_files_dir;
        const char* const hw_model;
        std::string copyright;
        std::string timezone;
        std::string os_ver;

        metadata(const char* const input_dir, const char* const output_dir,
                const char* const arg_files_dir, const char* const model,
                const std::string_view os_ver)
            : input_dir{input_dir}, output_dir{output_dir},
              arg_files_dir{arg_files_dir}, hw_model{model}, os_ver{os_ver}
        {
            // TODO: Actually get the timezone
            using std::string_literals::operator""s;
            timezone = "-07:00"s;
        }
    };

} // namespace sst::image
