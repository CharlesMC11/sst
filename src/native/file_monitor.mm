#include "file_monitor.hh"

#include <CoreServices/CoreServices.h>
#include <dispatch/queue.h>
#include <limits.h>

#include <string_view>

#include "inspector.hh"
#include "memory.hh"
#include "processor.hh"
#include "sorter.hh"

namespace sst::filesystem {

    monitor::monitor(dispatch_queue_t queue, CFMutableArrayRef buffer,
            const char directory[], const sst::processor& processor,
            FSEventStreamCallback callback)
        : queue_{queue}, buffer_{buffer}, processor_{processor}
    {
        auto dir_cfstr{CFStringCreateWithCString(
                nullptr, directory, kCFStringEncodingUTF8)};
        directory_.reset(dir_cfstr);

        sst::memory::CFPtr<CFArrayRef> paths{CFArrayCreate(nullptr,
                reinterpret_cast<const void**>(&dir_cfstr), 1,
                &kCFTypeArrayCallBacks)};

        FSEventStreamContext context{0, this, nullptr, nullptr, nullptr};
        stream_.reset(FSEventStreamCreate(nullptr, callback, &context,
                paths.get(), kFSEventStreamEventIdSinceNow, 0.1,
                kFSEventStreamCreateFlagFileEvents |
                        kFSEventStreamCreateFlagNoDefer));
    }

    void monitor::start() const
    {
        if (!directory_ || !stream_) [[unlikely]] {
            // FIXME: Print error messages
            return;
        }

        char input_dir[PATH_MAX];
        CFStringGetCString(directory_.get(), input_dir, sizeof(input_dir),
                kCFStringEncodingUTF8);

        std::cout << "[sstd:monitor] Running initial scan at '" << input_dir
                  << ".'" << std::endl;

        sst::inspector::scan_directory(buffer_, input_dir);
        if (!buffer_) [[unlikely]] {
            // FIXME: Print error messages
            return;
        }

        const CFIndex count{CFArrayGetCount(buffer_)};
        if (count == 0Z) {
            return;
        }

        sst::sorter::natural_sort(buffer_);

        char path[PATH_MAX];
        for (CFIndex i{0}; i < count; ++i) {
            const CFURLRef url{reinterpret_cast<CFURLRef>(
                    CFArrayGetValueAtIndex(buffer_, i))};

            if (CFURLGetFileSystemRepresentation(url, true,
                        reinterpret_cast<UInt8*>(path), sizeof(path)))
                    [[likely]] {
                processor_.send(path);
            }
        }

        if (stream_) [[likely]] {
            FSEventStreamSetDispatchQueue(stream_.get(), queue_);
            FSEventStreamStart(stream_.get());
        }
    }

} // namespace sst::filesystem
