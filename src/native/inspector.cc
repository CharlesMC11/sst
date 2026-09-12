#include "inspector.hh"

#include <CoreFoundation/CFArray.h>
#include <CoreServices/CoreServices.h>
#include <dirent.h>
#include <fcntl.h>
#include <string.h>
#include <sysexits.h>
#include <unistd.h>

#include <algorithm>
#include <cstdint>
#include <exception>
#include <expected>
#include <iostream>
#include <string>
#include <vector>

#include "file_monitor.hh"
#include "memory.hh"
#include "signatures.h"
#include "sorter.hh"

static constexpr std::size_t kAlignment{16UZ};
static constexpr auto kFlags{O_RDONLY | O_NOFOLLOW};

namespace sst::inspector {

bool is_image(int fd) {
  fcntl(fd, F_NOCACHE, 1);

  alignas(kAlignment) std::uint8_t buffer[kAlignment];
  if (read(fd, buffer, sizeof(buffer)) < 12Z) return false;

  return signatures::has_image_signature(buffer);
}

void scan_directory(CFMutableArrayRef buf, const char dir_name[]) {
  sst::memory::CFPtr<CFURLRef> dir_url{CFURLCreateFromFileSystemRepresentation(
      nullptr, reinterpret_cast<const UInt8*>(dir_name), strlen(dir_name),
      true)};
  if (!dir_url) return;

  sst::memory::CFPtr<CFURLEnumeratorRef> enumerator{
      CFURLEnumeratorCreateForDirectoryURL(
          nullptr, dir_url.get(), kCFURLEnumeratorDefaultBehavior, nullptr)};

  CFURLRef child_url;
  while (CFURLEnumeratorGetNextURL(enumerator.get(), &child_url, nullptr) ==
         kCFURLEnumeratorSuccess) {
    char path[PATH_MAX];

    if (!CFURLGetFileSystemRepresentation(
            child_url, true, reinterpret_cast<UInt8*>(path), PATH_MAX))
      continue;

    int fd{open(path, kFlags | O_CLOEXEC)};

    if (fd >= 0 && is_image(fd)) {
      CFArrayAppendValue(buf, child_url);
    }

    close(fd);
  }
}

void scan_directory(ConstFSEventStreamRef stream_ref,
                    void* client_callback_info, std::size_t num_events,
                    void* event_paths,
                    const FSEventStreamEventFlags event_flags[],
                    const FSEventStreamEventId event_ids[]) {
  const auto monitor{static_cast<filesystem::monitor*>(client_callback_info)};
  CFMutableArrayRef buffer{monitor->buffer()};
  CFArrayRemoveAllValues(buffer);

  std::size_t count{0UZ};
  auto paths{static_cast<const char**>(event_paths)};
  for (std::size_t i{0UZ}; i < num_events; ++i) {
    // Filter out APFS temporary files

    const char* path{paths[i]};
    const char* slash{strrchr(path, '/')};
    if (slash == nullptr || slash[1] == '\0' || slash[1] == '.') continue;

    const FSEventStreamEventFlags curr_flags{event_flags[i]};

    const bool is_file{(curr_flags & kFSEventStreamEventFlagItemIsFile) != 0};
    const bool is_relevant{
        (curr_flags & (kFSEventStreamEventFlagItemCreated |
                       kFSEventStreamEventFlagItemRenamed)) != 0};

    if (is_file && is_relevant) {
      int fd{open(path, kFlags | O_CLOEXEC)};

      if (fd >= 0 && is_image(fd)) {
        sst::memory::CFPtr<CFURLRef> url{
            CFURLCreateFromFileSystemRepresentation(
                nullptr, reinterpret_cast<const UInt8*>(path), strlen(path),
                false)};
        CFArrayAppendValue(buffer, url.get());
        ++count;
      }

      close(fd);
    }
  }

  if (count > 0UZ) sst::sorter::print_sorted(buffer);
}

}  // namespace sst::inspector
