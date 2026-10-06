#include "stream_context.hh"

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <dirent.h>
#include <dispatch/dispatch.h>
#include <fcntl.h>
#include <unistd.h>

#include <cerrno>
#include <format>
#include <iostream>
#include <ostream>
#include <string>
#include <system_error>

#include "memory.hh"
#include "orchestrator.hh"
#include "processor.hh"

extern "C" const int kIOFlags; // Defined in `orchestrator.cc`

sst::stream_context::stream_context(const ::FSEventStreamCallback callback,
        const ::dispatch_queue_t queue, sst::processor& processor,
        const char directory[], const CFTimeInterval latency)
    : processor_{processor}, dir_path_{directory}
{
    dir_fd_ = ::open(directory, kIOFlags | O_DIRECTORY);
    if (dir_fd_ == -1) [[unlikely]] {
        throw std::system_error{errno, std::generic_category(),
                std::format(
                        "[sstd:stream_context] Failed to open directory: '{}'",
                        directory)};
    }

    // TODO: This is technically not related to the stream
    sst::orchestrator::cleanup(dir_fd_, processor_, buffer_);

    const sst::memory::cf_ptr<::CFStringRef> dir_cfstr{
            ::CFStringCreateWithCString(
                    nullptr, directory, ::kCFStringEncodingUTF8)};
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
    if (stream_) [[likely]] {
        ::FSEventStreamStop(stream_.get());
        ::FSEventStreamInvalidate(stream_.get());
    }

    // TODO: This is technically not related to the stream
    sst::orchestrator::cleanup(dir_fd_, processor_, buffer_);

    if (dir_fd_ != -1 && ::close(dir_fd_) != 0) [[unlikely]] {
        std::println(std::cerr,
                "[sstd:stream_context] Failed to close directory '{}'",
                dir_fd_);
    };
}
