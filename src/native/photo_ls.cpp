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

#include "FileMonitor.hpp"
#include "Inspector.hpp"
#include "Memory.hpp"
#include "RuntimeContext.hpp"
#include "SignalHandler.hpp"
#include "Sorter.hpp"

int main(const int argc, const char *argv[]) {
  std::cout << "[sstd] Starting daemon..." << std::endl;
  const char *input_dir{(argc >= 2) ? argv[1] : "."};

  sst::memory::CFPtr<CFMutableArrayRef> buffer{
      CFArrayCreateMutable(nullptr, 0, &kCFTypeArrayCallBacks)};

  std::cout << "[sstd] Running initial scan at '" << input_dir << "'."
            << std::endl;
  sst::inspector::scanDirectory(buffer.get(), input_dir);
  sst::sorter::printSorted(buffer.get());

  dispatch_queue_t queue{dispatch_get_main_queue()};

  std::cout << "[sstd] Initializing watcher..." << std::endl;
  sst::filesystem::Monitor monitor{queue, buffer.get(), input_dir,
                                   sst::inspector::scanDirectory};
  monitor.start();
  std::cout << "[sstd] Initialized to watch '" << input_dir << "'."
            << std::endl;

  sst::runtime::Context context{queue, buffer.get(), monitor};
  sst::runtime::registerSignalHandler(SIGTERM, context);
  sst::runtime::registerSignalHandler(SIGINT, context);

  std::cout << "[sstd] Dispatching. Press CTRL-C to stop." << std::endl;
  dispatch_main();
}
