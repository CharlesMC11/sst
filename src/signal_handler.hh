#ifndef SST__SIGNAL_HANDLER__HH
#define SST__SIGNAL_HANDLER__HH

#include <dispatch/dispatch.h>

#include <string>
#include <vector>

namespace sst {

    namespace fs {

        class monitor;

    } // namespace fs

    namespace runtime {

        struct context final {
            const ::dispatch_queue_t queue;
            const std::vector<std::string>& buffer;
            const sst::fs::monitor& monitor;
        };

        void register_signal_handler(
                int sig, const sst::runtime::context context) noexcept;

    } // namespace runtime

} // namespace sst

#endif // SST__SIGNAL_HANDLER__HH
