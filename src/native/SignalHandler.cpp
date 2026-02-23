#include "SignalHandler.hpp"
#include "RuntimeContext.hpp"

#include <dispatch/dispatch.h>
#include <sysexits.h>

#include <csignal>
#include <iostream>

namespace sst::runtime {

void registerSignalHandler(int signal, Context context) {
  std::signal(signal, SIG_IGN);

  dispatch_source_t signal_source{dispatch_source_create(
      DISPATCH_SOURCE_TYPE_SIGNAL, signal, 0, context.queue)};

  dispatch_source_set_event_handler(signal_source, ^{
    std::cerr << "\n[sstd] Shutdown signal received. Cleaning up...\n";
    std::exit(EX_OK);
  });

  dispatch_resume(signal_source);
}

} // namespace sst::runtime
