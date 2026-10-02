#ifndef SST__FILE_MONITOR__HH
#define SST__FILE_MONITOR__HH

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <dispatch/queue.h>

#include "memory.hh"
#include "processor.hh"

namespace sst::filesystem {

    class monitor final {
    public:
        explicit monitor(dispatch_queue_t queue, CFMutableArrayRef buffer,
                const char directory[], const sst::processor& processor,
                FSEventStreamCallback callback);

        void start() const;

        [[nodiscard]] CFStringRef directory() const noexcept
        {
            return directory_.get();
        }

        [[nodiscard]] CFMutableArrayRef buffer() noexcept { return buffer_; }

    private:
        dispatch_queue_t queue_;
        CFMutableArrayRef buffer_;
        const sst::processor& processor_;
        memory::CFPtr<CFStringRef> directory_;
        memory::CFPtr<FSEventStreamRef> stream_{nullptr};
    };

} // namespace sst::filesystem

#endif // SST__FILE_MONITOR__HH
