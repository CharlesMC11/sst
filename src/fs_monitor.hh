#ifndef SST__FILE_MONITOR__HH
#define SST__FILE_MONITOR__HH

#include <CoreServices/CoreServices.h>
#include <dispatch/queue.h>

#include <string>
#include <vector>

#include "memory.hh"

namespace sst {

    class processor;

    namespace fs {

        class monitor final {
        public:
            [[nodiscard]] explicit monitor(std::vector<std::string>& buffer,
                    const ::FSEventStreamCallback callback,
                    const ::dispatch_queue_t queue, sst::processor& processor,
                    const char directory[]);

            ~monitor() noexcept;

            monitor(const monitor&) = delete;
            monitor(monitor&&) = delete;

            auto operator=(const monitor&) -> monitor& = delete;
            auto operator=(monitor&&) -> monitor& = delete;

            void start();

            [[nodiscard]] int dir_fd() const noexcept { return dir_fd_; }

            [[nodiscard]] auto buffer() noexcept -> std::vector<std::string>&
            {
                return buffer_;
            }

            [[nodiscard]] auto processor() const noexcept
                    -> const sst::processor&
            {
                return processor_;
            }

        private:
            std::vector<std::string>& buffer_;
            sst::memory::CFPtr<::FSEventStreamRef> stream_{nullptr};

            ::dispatch_queue_t queue_{nullptr};
            sst::processor& processor_;

            const char* directory_{nullptr};
            int dir_fd_{-1};
        };

    } // namespace fs

} // namespace sst

#endif // SST__FILE_MONITOR__HH
