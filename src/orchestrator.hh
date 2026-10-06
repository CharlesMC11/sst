#pragma once

#include <CoreServices/CoreServices.h>

#include <cstddef>
#include <string>
#include <vector>

namespace sst {

    class processor;

    namespace orchestrator {

        void cleanup(const processor& processor, int dir_fd,
                std::vector<std::string>& files);

        void orchestrate(::ConstFSEventStreamRef stream_ref,
                void* client_callback_info, std::size_t num_events,
                void* event_paths,
                const ::FSEventStreamEventFlags event_flags[],
                const ::FSEventStreamEventId event_ids[]);

    } // namespace orchestrator

} // namespace sst
