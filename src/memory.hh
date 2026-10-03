#ifndef SST__MEMORY__HH
#define SST__MEMORY__HH

#include <CoreFoundation/CFBase.h>
#include <CoreServices/CoreServices.h>

#include <memory>

namespace sst::memory {

    template<typename T>
    struct CFReleaser final {
        void operator()(T ptr) const
        {
            if (ptr) [[likely]] {
                ::CFRelease(ptr);
            }
        }
    };

    template<>
    struct CFReleaser<::FSEventStreamRef> {
        void operator()(::FSEventStreamRef stream) const
        {
            if (stream) [[likely]] {
                ::FSEventStreamRelease(stream);
            }
        }
    };

    template<typename T>
    using CFPtr = std::unique_ptr<std::remove_pointer_t<T>, CFReleaser<T>>;

} // namespace sst::memory

#endif // SST__MEMORY__HH
