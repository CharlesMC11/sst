#pragma once

#include <cstdint>
#include <expected>
#include <string>
#include <vector>

namespace sst::scanner {

using ScanResult = std::expected<std::vector<std::string>, uint32_t>;

ScanResult collect_images(const char dirname[]);

}  // namespace sst::scanner
