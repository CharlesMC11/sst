#include "file_monitor.hh"

#include <CoreServices/CoreServices.h>
#include <dispatch/queue.h>

#include "inspector.hh"
#include "memory.hh"

namespace sst::filesystem {

monitor::monitor(dispatch_queue_t queue, CFMutableArrayRef buffer,
                 const char directory[], FSEventStreamCallback callback)
    : queue_{queue}, buffer_{buffer} {
  auto dir_cfstr{
      CFStringCreateWithCString(nullptr, directory, kCFStringEncodingUTF8)};
  directory_.reset(dir_cfstr);

  sst::memory::CFPtr<CFArrayRef> paths{
      CFArrayCreate(nullptr, reinterpret_cast<const void**>(&dir_cfstr), 1,
                    &kCFTypeArrayCallBacks)};

  FSEventStreamContext context{0, static_cast<void*>(this), nullptr, nullptr,
                               nullptr};
  stream_.reset(FSEventStreamCreate(
      nullptr, callback, &context, paths.get(), kFSEventStreamEventIdSinceNow,
      0.1,
      kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer));
}

void monitor::start() const {
  if (stream_) {
    FSEventStreamSetDispatchQueue(stream_.get(), queue_);
    FSEventStreamStart(stream_.get());
  }
}

}  // namespace sst::filesystem
