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

#include "file_monitor.hh"
#include "inspector.hh"
#include "memory.hh"
#include "runtime_context.hh"
#include "signal_handler.hh"
#include "sorter.hh"

int main(const int argc, const char* argv[]) {
  std::cout << "[sstd] Starting daemon…" << std::endl;
  const char* input_dir{(argc >= 2) ? argv[1] : "."};

  sst::memory::CFPtr<CFMutableArrayRef> buffer{
      CFArrayCreateMutable(nullptr, 0, &kCFTypeArrayCallBacks)};

  std::cout << "[sstd] Running initial scan at '" << input_dir << ".'"
            << std::endl;
  sst::inspector::scan_directory(buffer.get(), input_dir);
  sst::sorter::print_sorted(buffer.get());

  dispatch_queue_t queue{dispatch_get_main_queue()};

  std::cout << "[sstd] Initializing watcher…" << std::endl;
  sst::filesystem::monitor monitor{queue, buffer.get(), input_dir,
                                   sst::inspector::scan_directory};
  monitor.start();
  std::cout << "[sstd] Initialized to watch '" << input_dir << ".'"
            << std::endl;

  sst::runtime::context context{queue, buffer.get(), monitor};
  sst::runtime::register_signal_handler(SIGTERM, context);
  sst::runtime::register_signal_handler(SIGINT, context);

  std::cout << "[sstd] Dispatching. Press CTRL-C to stop." << std::endl;
  dispatch_main();
}
