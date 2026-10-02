#ifndef SST__INSPECTOR__HH
#define SST__INSPECTOR__HH

#include <CoreFoundation/CFArray.h>
#include <CoreServices/CoreServices.h>

#include <cstddef>

namespace sst::inspector {

    void scan_directory(CFMutableArrayRef buf, const char dir_name[]);

    void scan_directory(ConstFSEventStreamRef stream_ref,
            void* client_callback_info, std::size_t num_events,
            void* event_paths, const FSEventStreamEventFlags event_flags[],
            const FSEventStreamEventId event_ids[]);

} // namespace sst::inspector

#endif // SST__INSPECTOR__HH
