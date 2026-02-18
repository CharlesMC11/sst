#include <limits.h>
#include <stdlib.h>
#include <sysexits.h>

#include <algorithm>
#include <iostream>
#include <string>
#include <vector>

#include "Scanner.hpp"
#include "Sorter.hpp"

uint32_t collect_images(const char* dirname, std::vector<std::string>& list);

int main(const int argc, const char* argv[]) {
  char input_absolute_path[PATH_MAX];

  if (realpath((argc >= 2) ? argv[1] : ".", input_absolute_path) == nullptr)
    return EX_NOINPUT;

  std::vector<std::string> list;
  try {
    const auto result{sst::scanner::collect_images(input_absolute_path, list)};
    if (result > 0) return result;

    std::sort(list.begin(), list.end(), sst::sorter::natural_sort);
  } catch (const std::bad_alloc& e) {
    std::cerr << "Memory exhaustion: " << e.what() << '\n';
    return EX_OSERR;
  }

  for (const auto& p : list)
    std::cout << input_absolute_path << '/' << p << '\n';

  return EX_OK;
}
