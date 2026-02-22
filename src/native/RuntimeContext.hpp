#pragma once

#include "FileMonitor.hpp"

namespace sst::rt {

struct RuntimeContext {
  const dispatch_queue_t queue;
  const CFMutableArrayRef buffer;
  const fs::FileMonitor &watcher;
};

} // namespace sst::rt
