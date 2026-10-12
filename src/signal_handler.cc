#include "signal_handler.hh"

#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#include <os/log.h>

#include <csignal>

namespace sst {

    extern const ::os_log_t g_logger;

    void signals::register_handler(
            const int sig, dispatch_queue_t queue) noexcept
    {
        std::signal(sig, SIG_IGN);
        const auto sig_src{::dispatch_source_create(
                DISPATCH_SOURCE_TYPE_SIGNAL, sig, 0U, queue)};

        ::dispatch_source_set_event_handler(sig_src, ^{
          os_log_error(g_logger,
                  "[sstd:signal_handler] Shutdown signal received. Cleaning "
                  "up…\n");

          ::CFRunLoopStop(::CFRunLoopGetMain());
        });

        ::dispatch_resume(sig_src);
    }

} // namespace sst
