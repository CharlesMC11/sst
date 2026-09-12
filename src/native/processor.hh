#ifndef SST__PROCESSOR
#define SST__PROCESSOR

#include <sys/wait.h>
#include <unistd.h>

#include <array>
#include <exception>
#include <iostream>
#include <limits>
#include <regex>
#include <string>
#include <string_view>

extern char** environ;

namespace sst {

namespace image {

struct metadata final {
  std::string output_dir;
  std::string hardware;
  std::string software;
  std::string timezone;
  std::string arg_files_dir;
};

}  // namespace image

class processor final {
 public:
  explicit processor(image::metadata metadata);

  ~processor() {
    send("-stay_open\nFalse\n-execute\n");
    close(fds_[1]);
    waitpid(pid_, nullptr, 0);
  }

  void send(std::string_view args) const noexcept {
    std::cout << "[sstd:processor] Received args: '" << args << "'..."
              << std::endl;

    write(fds_[1], args.data(), args.size());
  }

 private:
  image::metadata metadata_;
  int fds_[2];
  pid_t pid_{-1};
  std::array<std::string, 7> formatted_args_;
};

}  // namespace sst

#endif  // SST__PROCESSOR
