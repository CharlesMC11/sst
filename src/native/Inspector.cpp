#include "Inspector.hpp"

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

#include "FileMonitor.hpp"
#include "Memory.hpp"
#include "Signatures.h"
#include "Sorter.hpp"

static constexpr size_t kAlignment{16};
static constexpr auto kFlags{O_RDONLY | O_NOFOLLOW};

namespace sst::inspector {

bool isImage(int fd) {
  fcntl(fd, F_NOCACHE, 1);

  alignas(kAlignment) uint8_t buffer[kAlignment];
  if (read(fd, buffer, sizeof(buffer)) < 12)
    return false;

  return signatures::hasImageSignature(buffer);
}

void scanDirectory(CFMutableArrayRef buffer, const char dirname[]) {

  sst::memory::CFPtr<CFURLRef> dirUrl{CFURLCreateFromFileSystemRepresentation(
      nullptr, reinterpret_cast<const UInt8 *>(dirname), strlen(dirname),
      true)};
  if (!dirUrl)
    return;

  sst::memory::CFPtr<CFURLEnumeratorRef> enumerator{
      CFURLEnumeratorCreateForDirectoryURL(
          nullptr, dirUrl.get(), kCFURLEnumeratorDefaultBehavior, nullptr)};

  CFURLRef childUrl;
  while (CFURLEnumeratorGetNextURL(enumerator.get(), &childUrl, nullptr) ==
         kCFURLEnumeratorSuccess) {
    char path[PATH_MAX];

    if (!CFURLGetFileSystemRepresentation(
            childUrl, true, reinterpret_cast<UInt8 *>(path), PATH_MAX))
      continue;

    int fd{open(path, kFlags | O_CLOEXEC)};

    if (fd >= 0 && isImage(fd)) {
      CFArrayAppendValue(buffer, childUrl);
    }

    close(fd);
  }
}

void scanDirectory(ConstFSEventStreamRef streamRef, void *clientCallbackInfo,
                   size_t numEvents, void *eventPaths,
                   const FSEventStreamEventFlags eventFlags[],
                   const FSEventStreamEventId eventIds[]) {
  const auto monitor{static_cast<filesystem::Monitor *>(clientCallbackInfo)};
  auto buffer{monitor->buffer()};
  CFArrayRemoveAllValues(buffer);

  size_t count{0};
  auto paths = static_cast<const char **>(eventPaths);
  for (size_t i{0}; i < numEvents; ++i) {
    // Filter out APFS temporary files

    const char *path{paths[i]};
    const char *slash{strrchr(path, '/')};
    if (slash == nullptr || slash[1] == '\0' || slash[1] == '.')
      continue;

    if (eventFlags[i] & kFSEventStreamEventFlagItemIsFile &
        (kFSEventStreamEventFlagItemCreated |
         kFSEventStreamEventFlagItemRenamed)) {
      int fd{open(path, kFlags | O_CLOEXEC)};

      if (fd >= 0 && isImage(fd)) {
        sst::memory::CFPtr<CFURLRef> url{
            CFURLCreateFromFileSystemRepresentation(
                nullptr, reinterpret_cast<const UInt8 *>(path), strlen(path),
                false)};
        CFArrayAppendValue(buffer, url.get());
        ++count;
      }

      close(fd);
    }
  }

  if (count > 0)
    sst::sorter::printSorted(buffer);
}

} // namespace sst::inspector
