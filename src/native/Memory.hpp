#pragma once

#include <CoreFoundation/CFBase.h>
#include <CoreServices/CoreServices.h>

#include <memory>

namespace sst::memory {

template <typename T> struct CFReleaser {
  void operator()(T ptr) const {
    if (ptr)
      CFRelease(ptr);
  }
};

template <> struct CFReleaser<FSEventStreamRef> {
  void operator()(FSEventStreamRef stream) const {
    if (stream) {
      FSEventStreamStop(stream);
      FSEventStreamInvalidate(stream);
      FSEventStreamRelease(stream);
    }
  }
};

template <typename T>
using CFPtr = std::unique_ptr<std::remove_pointer_t<T>, CFReleaser<T>>;

} // namespace sst::memory
