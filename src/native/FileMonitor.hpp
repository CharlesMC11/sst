#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <dispatch/queue.h>

#include "Memory.hpp"

namespace sst::filesystem {

class Monitor {
public:
  explicit Monitor(dispatch_queue_t queue, CFMutableArrayRef buffer,
                   const char dirname[], FSEventStreamCallback callback);

  void start() const;

  CFStringRef directory() const noexcept { return directory_.get(); }

  CFMutableArrayRef buffer() noexcept { return buffer_; }

private:
  dispatch_queue_t queue_;
  CFMutableArrayRef buffer_;
  sst::memory::CFPtr<CFStringRef> directory_;
  sst::memory::CFPtr<FSEventStreamRef> stream_{nullptr};
};

} // namespace sst::filesystem
