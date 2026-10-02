#ifndef SST__PROCESSOR__HH
#define SST__PROCESSOR__HH

#include <sys/wait.h>
#include <unistd.h>

#include <array>
#include <exception>
#include <format>
#include <iostream>
#include <limits>
#include <regex>
#include <string>
#include <string_view>

namespace sst {

    namespace image {

        struct metadata final {
            std::string output_dir;
            std::string hardware;
            std::string software;
            std::string timezone;
            std::string arg_files_dir;
        };

    } // namespace image

    class processor final {
    public:
        explicit processor(const image::metadata& metadata);

        ~processor();

        void send(std::string_view args) const noexcept
        {
            std::cout << "[sstd:processor] Received args: " << args
                      << std::endl;

            const std::string formatted_arg{
                    std::format("{}\n-execute\n", args)};
            write(fds_[1], formatted_arg.data(), formatted_arg.size());
        }

    private:
        image::metadata metadata_;
        int fds_[2];
        pid_t pid_{-1};
        std::array<std::string, 7> formatted_args_;
    };

} // namespace sst

#endif // SST__PROCESSOR__HH
