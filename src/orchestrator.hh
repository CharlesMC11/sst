#pragma once

#include <CoreServices/CoreServices.h>

#include <cstddef>

namespace sst::orchestrator {

    void orchestrate(::ConstFSEventStreamRef stream_ref,
            void* client_callback_info, std::size_t num_events,
            void* event_paths, const ::FSEventStreamEventFlags event_flags[],
            const ::FSEventStreamEventId event_ids[]);

} // namespace sst::orchestrator
