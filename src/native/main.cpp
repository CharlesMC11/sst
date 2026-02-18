#include <limits.h>
#include <stdlib.h>
#include <sysexits.h>

#include <algorithm>
#include <iostream>
#include <string>
#include <vector>

#include "Scanner.hpp"
#include "Sorter.hpp"

int main(const int argc, const char* argv[]) {
  char input_absolute_path[PATH_MAX];

  if (realpath((argc >= 2) ? argv[1] : ".", input_absolute_path) == nullptr)
    return EX_NOINPUT;

  auto result{sst::scanner::collect_images(input_absolute_path)};
  if (!result) return result.error();

  auto& list{result.value()};
  std::sort(list.begin(), list.end(), sst::sorter::natural_sort);

  for (const auto& p : list)
    std::cout << input_absolute_path << '/' << p << '\n';

  return EX_OK;
}
