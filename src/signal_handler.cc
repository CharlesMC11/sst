#include "signal_handler.hh"

#include <dispatch/dispatch.h>
#include <sysexits.h>

#include <csignal>
#include <cstdlib>
#include <iostream>

void sst::runtime::register_signal_handler(int sig, context context) noexcept
{
    std::signal(sig, SIG_IGN);

    auto signal_source{::dispatch_source_create(
            DISPATCH_SOURCE_TYPE_SIGNAL, sig, 0U, context.queue)};

    ::dispatch_source_set_event_handler(signal_source, ^{
      std::cerr << "\n[sstd] Shutdown signal received. Cleaning up…\n";

      // FIXME: This prevents the destructors from being called.
      std::exit(EX_OK);
    });

    ::dispatch_resume(signal_source);
}
