#include "Scanner.hpp"

#include <dirent.h>
#include <fcntl.h>
#include <sysexits.h>
#include <unistd.h>

#include <cstdint>
#include <exception>
#include <expected>

#include "Signatures.h"

namespace sst::scanner {

ScanResult collect_images(const char dirname[]) {
  int dfd{open(dirname, O_RDONLY | O_DIRECTORY)};
  if (dfd < 0) return std::unexpected{EX_NOINPUT};

  DIR* dirp{fdopendir(dfd)};
  if (dirp == nullptr) {
    close(dfd);
    return std::unexpected{EX_NOINPUT};
  }

  dirent* entry;
  std::vector<std::string> list;
  while ((entry = readdir(dirp)) != nullptr) {
    if (entry->d_type != DT_REG) continue;

    int fd{openat(dfd, entry->d_name, O_RDONLY | O_CLOEXEC)};
    if (fd < 0) continue;

    fcntl(fd, F_NOCACHE, 1);

    alignas(16) uint8_t buffer[16];
    if (read(fd, buffer, sizeof(buffer)) < 12) {
      close(fd);
      continue;
    }

    if (signatures::is_image(buffer)) {
      try {
        list.emplace_back(entry->d_name);
      } catch (const std::bad_alloc& e) {
        close(fd);
        closedir(dirp);
        return std::unexpected{EX_OSERR};
      }
    }
    close(fd);
  }
  closedir(dirp);

  return list;
}

}  // namespace sst::scanner
