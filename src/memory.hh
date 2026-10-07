#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>

#include <memory>

namespace sst::memory {

    template<typename T>
    struct cf_releaser final {
        void operator()(T ptr) const noexcept
        {
            if (ptr) [[likely]] {
                ::CFRelease(ptr);
            }
        }
    };

    template<>
    struct cf_releaser<::FSEventStreamRef> final {
        void operator()(::FSEventStreamRef stream) const noexcept
        {
            if (stream) [[likely]] {
                ::FSEventStreamRelease(stream);
            }
        }
    };

    template<typename T>
    using cf_ptr = std::unique_ptr<std::remove_pointer_t<T>, cf_releaser<T>>;

} // namespace sst::memory
