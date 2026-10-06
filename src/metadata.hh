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
        const char* const hardware;
        std::string software;
        std::string timezone;

        metadata(const char* const input_dir, const char* const output_dir,
                const char* const arg_files_dir, const char* const hardware,
                const std::string_view software)
            : input_dir{input_dir}, output_dir{output_dir},
              arg_files_dir{arg_files_dir}, hardware{hardware},
              software{software}
        {
            // TODO: Actually get the timezone
            using std::string_literals::operator""s;
            timezone = "-07:00"s;
        }
    };

} // namespace sst::image
