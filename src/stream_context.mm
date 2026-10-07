#include "stream_context.hh"

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <dirent.h>
#include <dispatch/dispatch.h>
#include <fcntl.h>
#include <unistd.h>

#include <cerrno>
#include <cstdio>
#include <format>
#include <iostream>
#include <ostream>
#include <string>
#include <system_error>

#include "memory.hh"
#include "orchestrator.hh"
#include "processor.hh"

sst::stream_context::stream_context(const ::FSEventStreamCallback callback,
        const ::dispatch_queue_t queue, sst::processor& processor,
        const char* const input_dir, int input_dir_fd,
        const CFTimeInterval latency)
    : processor_{processor}, dir_fd_{input_dir_fd}
{
    const sst::memory::cf_ptr<::CFStringRef> dir_cfstr{
            ::CFStringCreateWithCString(
                    nullptr, input_dir, ::kCFStringEncodingUTF8)};
    const void* dir_container[]{dir_cfstr.get()};
    const sst::memory::cf_ptr<::CFArrayRef> paths{::CFArrayCreate(
            nullptr, dir_container, 1Z, &::kCFTypeArrayCallBacks)};

    FSEventStreamContext context{.version = 0Z,
            .info = this,
            .retain = nullptr,
            .release = nullptr,
            .copyDescription = nullptr};
    stream_.reset(::FSEventStreamCreate(nullptr, callback, &context,
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
