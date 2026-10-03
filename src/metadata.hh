#ifndef SST__METADATA__HH
#define SST__METADATA__HH

#include <string>
#include <string_view>

namespace sst::image {

    struct metadata final {
        const std::string output_dir;
        const std::string arg_files_dir;
        const std::string hardware;
        const std::string software;
        std::string timezone;

        metadata(std::string_view output_dir, std::string_view arg_files_dir,
                std::string_view hardware, std::string_view software)
            : output_dir{output_dir}, arg_files_dir{arg_files_dir},
              hardware{hardware}, software{software}
        {
            // TODO: Actually get the timezone
            using std::string_literals::operator""s;
            timezone = "-07:00"s;
        }
    };

} // namespace sst::image

#endif // SST__METADATA__HH
