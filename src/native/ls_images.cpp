#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <sysexits.h>
#include <unistd.h>

#include <algorithm>
#include <iostream>
#include <vector>

#include "compare_filenames.hpp"

extern "C" int is_image(int fd);

int main(const int argc, const char* argv[]) {
  char input_absolute_path[PATH_MAX];

  if (realpath((argc >= 2) ? argv[1] : ".", input_absolute_path) == nullptr)
    return EX_NOINPUT;

  int dfd{open(input_absolute_path, O_RDONLY | O_DIRECTORY)};
  if (dfd < 0) return EX_NOINPUT;

  std::vector<std::string> list;

  DIR* dirp{fdopendir(dfd)};
  dirent* entry;
  while ((entry = readdir(dirp)) != nullptr) {
    int fd{openat(dfd, entry->d_name, O_RDONLY | O_CLOEXEC)};
    if (fd < 0) continue;

    if (is_image(fd)) {
      list.emplace_back(entry->d_name);
    }
    close(fd);
  }
  closedir(dirp);

  std::sort(list.begin(), list.end(), compare_filenames);

  for (const auto& p : list) {
    std::cout << input_absolute_path << '/' << p << '\n';
  }

  return EX_OK;
}
