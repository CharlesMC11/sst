#include "signal_handler.hh"

#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>

#include <csignal>
#include <cstdio>

void sst::signals::register_handler(
        const int sig, dispatch_queue_t queue) noexcept
{
    std::signal(sig, SIG_IGN);
    const auto sig_src{::dispatch_source_create(
            DISPATCH_SOURCE_TYPE_SIGNAL, sig, 0U, queue)};

    ::dispatch_source_set_event_handler(sig_src, ^{
      std::fprintf(stderr,
              "[sstd:signal_handler] Shutdown signal received. Cleaning "
              "up…\n");

      ::CFRunLoopStop(::CFRunLoopGetMain());
    });

    ::dispatch_resume(sig_src);
}
