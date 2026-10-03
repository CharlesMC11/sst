#ifndef SST__INSPECTOR__HH
#define SST__INSPECTOR__HH

#include <CoreServices/CoreServices.h>

#include <cstddef>
#include <string>
#include <vector>

namespace sst::inspector {

    void scan_directory(::ConstFSEventStreamRef stream_ref,
            void* client_callback_info, std::size_t num_events,
            void* event_paths, const ::FSEventStreamEventFlags event_flags[],
            const ::FSEventStreamEventId event_ids[]);

} // namespace sst::inspector

#endif // SST__INSPECTOR__HH
