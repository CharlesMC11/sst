#include "exiftool_args.hh"

#include <format>
#include <string>

sst::exiftool_args::exiftool_args(const int input_dir_fd,
        const char* exiftool_path, const char* const output_dir,
        const char* const arg_files_dir)
    : input_dir_fd{input_dir_fd},
      argv_{exiftool_path, "-stay_open", "True", "-@", "-", "-common_args",
              "-struct", "-preserve", "-o", output_dir, "-@", nullptr, nullptr}
{
    static const std::string args_path{
            std::format("{}/sstd.args", arg_files_dir)};
    argv_[11UZ] = args_path.c_str();
}
