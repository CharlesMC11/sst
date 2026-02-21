#include "Watcher.hpp"

#include <CoreServices/CoreServices.h>
#include <dispatch/dispatch.h>

#include "Scanner.hpp"

namespace sst::watcher {

Watcher::Watcher(const char dirname[])
    : path_{CFStringCreateWithCString(nullptr, dirname, kCFStringEncodingUTF8)},
      paths_{CFArrayCreate(nullptr, (const void**)&path_, 1,
                           &kCFTypeArrayCallBacks)},
      stream_{FSEventStreamCreate(nullptr, &sst::scanner::collect_images,
                                  nullptr, paths_,
                                  kFSEventStreamEventIdSinceNow, 1,
                                  kFSEventStreamCreateFlagFileEvents |
                                      kFSEventStreamCreateFlagNoDefer)} {}

Watcher::~Watcher() {
  stop();
  if (paths_) CFRelease(paths_);
  if (path_) CFRelease(path_);
}

void Watcher::start() const {
  if (stream_) {
    dispatch_queue_t queue{
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)};
    FSEventStreamSetDispatchQueue(stream_, queue);
    FSEventStreamStart(stream_);
  }
}

void Watcher::stop() const {
  if (stream_) {
    FSEventStreamStop(stream_);
    FSEventStreamInvalidate(stream_);
    FSEventStreamRelease(stream_);
  }
}

}  // namespace sst::watcher
