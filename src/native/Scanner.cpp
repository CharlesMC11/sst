#include "Scanner.hpp"

#include <CoreServices/CoreServices.h>
#include <dirent.h>
#include <fcntl.h>
#include <sysexits.h>
#include <unistd.h>

#include <algorithm>
#include <cstdint>
#include <exception>
#include <expected>
#include <iostream>
#include <string>
#include <vector>

#include "Signatures.h"
#include "Sorter.hpp"

#define O_FLAGS O_RDONLY | O_NOFOLLOW

static constexpr size_t ALIGNMENT{16};

namespace sst::scanner {

bool is_image(int fd) {
  fcntl(fd, F_NOCACHE, 1);

  alignas(ALIGNMENT) uint8_t buffer[ALIGNMENT];
  if (read(fd, buffer, sizeof(buffer)) < 12) return false;

  return signatures::has_image_signature(buffer);
}

ScanResult collect_images(const char dirname[]) {
  int dfd{open(dirname, O_FLAGS | O_DIRECTORY)};
  if (dfd < 0) return std::unexpected{EX_NOINPUT};

  DIR* dirp{fdopendir(dfd)};
  if (dirp == nullptr) {
    close(dfd);
    return std::unexpected{EX_NOINPUT};
  }

  dirent* entry;
  std::vector<std::string> filtered;
  while ((entry = readdir(dirp)) != nullptr) {
    if (entry->d_type != DT_REG) continue;

    int fd{openat(dfd, entry->d_name, O_FLAGS | O_CLOEXEC)};
    if (fd < 0) continue;

    if (is_image(fd)) {
      try {
        filtered.emplace_back(entry->d_name);
      } catch (const std::bad_alloc& e) {
        close(fd);
        closedir(dirp);
        std::cerr << "Could not allocate for vector" << std::endl;
        return std::unexpected{EX_OSERR};
      }
    }
    close(fd);
  }
  closedir(dirp);

  return filtered;
}

void print_sorted(std::vector<std::string>& list) {
  std::sort(list.begin(), list.end(), sorter::natural_sort);

  for (const auto& p : list) std::cout << p << '\n';
  std::cout << std::flush;
}

void collect_images(ConstFSEventStreamRef streamRef, void* clientCallbackInfo,
                    size_t numEvents, void* eventPaths,
                    const FSEventStreamEventFlags flags[],
                    const FSEventStreamEventId ids[]) {
  auto paths = static_cast<const char**>(eventPaths);

  std::vector<std::string> filtered;

  for (size_t i{0}; i < numEvents; ++i) {
    if (flags[i] & (kFSEventStreamEventFlagItemCreated |
                    kFSEventStreamEventFlagItemRenamed)) {
      int fd{open(paths[i], O_FLAGS | O_CLOEXEC)};
      if (fd < 0) continue;

      if (is_image(fd)) {
        try {
          filtered.emplace_back(paths[i]);
        } catch (const std::bad_alloc&) {
          close(fd);
          std::cerr << "Could not allocate for vector" << std::endl;
          std::exit(EX_OSERR);
        };
      }

      close(fd);
    }
  }

  print_sorted(filtered);
}

}  // namespace sst::scanner
