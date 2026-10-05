#pragma once

#include <chrono>
#include <format>
#include <string>
#include <string_view>

namespace sst::image {

    struct metadata final {
        std::string output_dir;
        std::string arg_files_dir;
        std::string hardware;
        std::string software;
        std::string timezone;

        metadata(const std::string_view output_dir,
                const std::string_view arg_files_dir,
                const std::string_view hardware,
                const std::string_view software)
            : output_dir{output_dir}, arg_files_dir{arg_files_dir},
              hardware{hardware}, software{software}
        {
            // TODO: Actually get the timezone
            using std::string_literals::operator""s;
            timezone = "-07:00"s;
        }
    };

} // namespace sst::image
