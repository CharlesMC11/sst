#include "stream_context.hh"

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <dispatch/dispatch.h>

#include "memory.hh"
#include "orchestrator.hh"

sst::stream_context::stream_context(sst::orchestrator& orchestrator,
        const ::dispatch_queue_t queue, const CFTimeInterval latency)
{
    const sst::memory::cf_ptr<::CFStringRef> dir_cfstr{
            ::CFStringCreateWithCString(nullptr, orchestrator.input_dir_path(),
                    ::kCFStringEncodingUTF8)};
    const void* dir_container[]{dir_cfstr.get()};
    const sst::memory::cf_ptr<::CFArrayRef> paths{::CFArrayCreate(
            nullptr, dir_container, 1Z, &::kCFTypeArrayCallBacks)};

    FSEventStreamContext context{.version = 0Z,
            .info = &orchestrator,
            .retain = nullptr,
            .release = nullptr,
            .copyDescription = nullptr};
    stream_.reset(::FSEventStreamCreate(nullptr, orchestrator::run, &context,
            paths.get(), ::kFSEventStreamEventIdSinceNow, latency,
            ::kFSEventStreamCreateFlagFileEvents));

    if (stream_) [[likely]] {
        ::FSEventStreamSetDispatchQueue(stream_.get(), queue);
        ::FSEventStreamStart(stream_.get());
    }
}

sst::stream_context::~stream_context() noexcept
{
    if (stream_) [[unlikely]] {
        shutdown();
    }
}

void sst::stream_context::shutdown() noexcept
{
    if (stream_) [[likely]] {
        ::FSEventStreamStop(stream_.get());
        ::FSEventStreamInvalidate(stream_.get());
        stream_.reset(nullptr);
    }

    // CRITIAL: This class does not own `dir_fd_`!
}
