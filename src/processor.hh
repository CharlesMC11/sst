#ifndef SST__PROCESSOR__HH
#define SST__PROCESSOR__HH

#include <sys/types.h>

#include <array>
#include <string>
#include <string_view>

#include "metadata.hh"

namespace sst {

    class processor final {
    public:
        [[nodiscard]] explicit processor(const char* exiftool_path,
                const sst::image::metadata& metadata);

        ~processor();

        processor(const processor&) = delete;
        processor(processor&&) = delete;

        auto operator=(const processor&) -> processor& = delete;
        auto operator=(processor&&) -> processor& = delete;

        void send(std::string_view args) const;

    private:
        class pipe final {
        public:
            int fds[2UZ]{-1, -1};

            [[nodiscard]] pipe() noexcept;
            ~pipe() noexcept;

            pipe(const pipe&) = delete;
            pipe(pipe&&) = delete;

            auto operator=(const pipe&) -> pipe& = delete;
            auto operator=(pipe&&) -> pipe& = delete;

            void close(std::size_t idx) noexcept;

            [[nodiscard]] bool is_valid() const noexcept
            {
                return fds[0UZ] != -1 && fds[1UZ] != -1;
            }
        };

        const sst::image::metadata& metadata_;
        sst::processor::pipe pipe_;
        ::pid_t pid_{-1};
        std::array<std::string, 7UZ> formatted_args_;
    };

} // namespace sst

#endif // SST__PROCESSOR__HH
