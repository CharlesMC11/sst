#pragma once

#include <CoreServices/CoreServices.h>
#include <fcntl.h>

#include <cstddef>
#include <string>
#include <vector>

namespace sst {

    constexpr int kIOFlags{O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_CLOFORK};

    class processor;

    namespace orchestrator {

        /**
         * Manually clean up a directory
         *
         * @param processor
         * The processor bridge to ExifTool
         *
         * @param dir_fd
         * The directory’s file descriptor
         *
         * @param buffer
         * A buffer to save filenames to
         *
         * @param max_retries
         * The number of attempts to make if an I/O problem is encountered
         *
         * @returns
         * `true` if the function executed without any issues; `false`
         * otherwise
         */
        bool cleanup(const processor& processor, int dir_fd,
                std::vector<std::string>& buffer,
                unsigned max_retries = 5U) noexcept;

        void orchestrate(::ConstFSEventStreamRef stream_ref,
                void* client_callback_info, std::size_t num_events,
                void* event_paths,
                const ::FSEventStreamEventFlags event_flags[],
                const ::FSEventStreamEventId event_ids[]);

    } // namespace orchestrator

} // namespace sst
