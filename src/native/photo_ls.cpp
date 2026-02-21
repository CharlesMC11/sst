#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#include <limits.h>
#include <stdlib.h>
#include <sysexits.h>

#include <algorithm>
#include <csignal>
#include <iostream>
#include <string>
#include <vector>

#include "Scanner.hpp"
#include "Sorter.hpp"
#include "Watcher.hpp"

int main(const int argc, const char* argv[]) {
  std::cout << "[sstd] Starting daemon..." << std::endl;

  sst::watcher::Watcher watcher{(argc >= 2) ? argv[1] : "."};
  watcher.start();
  std::cout << "[sstd] Watcher initialized to watch '" << watcher.getPath()
            << "'." << std::endl;

  std::signal(SIGTERM, [](int) {
    std::cerr << "[sstd] Daemon terminated!" << std::endl;
    std::exit(EX_OK);
  });

  std::cout << "[sstd] Dispatching..." << std::endl;
  dispatch_main();
  std::cout << "[sstd] Daemon stopped." << std::endl;

  return EX_OK;
}
