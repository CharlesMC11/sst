#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>

namespace sst::watcher {

class Watcher {
 public:
  Watcher(const char dirname[]);
  ~Watcher();

  void start() const;
  void stop() const;

  CFStringRef getPath() const noexcept { return path_; }

 private:
  CFStringRef path_{nullptr};
  CFArrayRef paths_{nullptr};
  FSEventStreamRef stream_{nullptr};
};

}  // namespace sst::watcher
