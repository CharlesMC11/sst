#pragma once

namespace sst::image {

    struct metadata final {
        static constexpr char kRegexReplacePrefix[]{
                R"(Filename;s/^\D+(\d{4})-(\d{2})-(\d{2}) at (\d{2})\.(\d{2})\.(\d{2})(?: \((\d)\))?.+$)"};

        [[nodiscard]] static const char* os_version();
        [[nodiscard]] static const char* timezone();

        const char* const output_dir;
        const char* const arg_files_dir;
        const char* const hw_model;
    };

} // namespace sst::image
