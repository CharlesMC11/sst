#include "stream_context.hh"

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <Foundation/Foundation.h>
#include <dirent.h>
#include <dispatch/dispatch.h>
#include <fcntl.h>
#include <sys/types.h>
#include <unistd.h>

#include <cerrno>
#include <format>
#include <iostream>
#include <ostream>
#include <string>
#include <system_error>
#include <vector>

#include "memory.hh"
#include "processor.hh"
#include "signatures.hh"
#include "sorter.hh"

extern "C" const int kIOFlags{O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_CLOFORK};

sst::stream_context::stream_context(const ::FSEventStreamCallback callback,
        const ::dispatch_queue_t queue, sst::processor& processor,
        const char directory[], CFTimeInterval latency)
    : queue_{queue}, processor_{processor}, directory_{directory}
{
    dir_fd_ = ::open(directory, kIOFlags | O_DIRECTORY);
    if (dir_fd_ == -1) [[unlikely]] {
        throw std::system_error{errno, std::generic_category(),
                std::format(
                        "[sstd:stream_context] Failed to open directory: '{}'",
                        directory)};
    }

    cleanup();

    const sst::memory::CFPtr<::CFStringRef> dir_cfstr{
            ::CFStringCreateWithCString(
                    nullptr, directory, ::kCFStringEncodingUTF8)};
    const void* dir_container[]{dir_cfstr.get()};
    const sst::memory::CFPtr<::CFArrayRef> paths{::CFArrayCreate(nullptr,
            reinterpret_cast<const void**>(dir_container), 1,
            &::kCFTypeArrayCallBacks)};

    FSEventStreamContext context{0, this, nullptr, nullptr, nullptr};
    stream_.reset(::FSEventStreamCreate(::kCFAllocatorDefault, callback,
            &context, paths.get(), ::kFSEventStreamEventIdSinceNow, latency,
            ::kFSEventStreamCreateFlagFileEvents));

    if (stream_) [[likely]] {
        ::FSEventStreamSetDispatchQueue(stream_.get(), queue_);
        ::FSEventStreamStart(stream_.get());
    }
}

sst::stream_context::~stream_context() noexcept
{
    if (stream_) [[likely]] {
        ::FSEventStreamStop(stream_.get());
        ::FSEventStreamInvalidate(stream_.get());
    }

    cleanup();

    if (dir_fd_ != -1 && ::close(dir_fd_) != 0) [[unlikely]] {
        std::println(std::cerr,
                "[sstd:stream_context] Failed to close directory '{}'",
                dir_fd_);
    };
}

void sst::stream_context::cleanup()
{
    if (dir_fd_ == -1) [[unlikely]] {
        std::println(std::cerr,
                "[sstd:stream_context] No open directory file descriptor or "
                "event stream. Cannot start file system stream_context.");
        return;
    }

    // FIXME:
    // const int dir_fd_{::dup(dir_fd)};
    // if (dir_fd_ < 0) {
    //     std::cerr << "[sstd:stream_context] Failed to duplicate file
    //     descriptor\n"; return;
    // }

    DIR* dir_stream{::fdopendir(dir_fd_)};
    if (!dir_stream) [[unlikely]] {
        std::println(std::cerr,
                "[sstd:stream_context] Failed to open directory stream for "
                "file descriptor duplicate: {}",
                dir_fd_);

        if (::close(dir_fd_) != 0) {
            std::println(std::cerr,
                    "[sstd:stream_context] Failed to close directory file "
                    "descriptor");
        }
        return;
    }

    struct dirent* entry{nullptr};
    while ((entry = ::readdir(dir_stream))) {
        const char* filename{entry->d_name};

        if (filename[0] == '.' || entry->d_type != DT_REG) [[unlikely]] {
            continue;
        }

        const int fd{::openat(dir_fd_, filename, kIOFlags)};
        if (fd < 0) [[unlikely]] {
            continue;
        }

        if (sst::filter::is_image(fd)) [[likely]] {
            const std::string full_path{
                    std::format("{}/{}", directory_, filename)};
            buffer_.push_back(full_path);
            std::println(
                    "[sstd:stream_context] Found entry: {}", entry->d_name);
        }

        if (::close(fd) != 0) {
            // TODO: Some error message
        }
    }

    if (::fdclosedir(dir_stream) == -1) [[unlikely]] {
        std::cerr
                << "[sstd:stream_context] Failed to close directory stream.\n";
        return;
    }
    dir_stream = nullptr;

    sst::sorter::natural_sort(buffer_);
    for (const auto& file_path: buffer_) {
        processor_.send(file_path);
    }
}
