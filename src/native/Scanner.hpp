#pragma once

#include <CoreServices/CoreServices.h>

#include <cstdint>
#include <expected>
#include <vector>

namespace sst::scanner {

using ScanResult = std::expected<std::vector<std::string>, uint32_t>;

ScanResult collect_images(const char dirname[]);

void print_sorted(std::vector<std::string>& list);

void collect_images(ConstFSEventStreamRef streamRef, void* clientCallbackInfo,
                    size_t numEvents, void* eventPaths,
                    const FSEventStreamEventFlags flags[],
                    const FSEventStreamEventId ids[]);

}  // namespace sst::scanner
