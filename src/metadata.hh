#pragma once

namespace sst::image {

    struct metadata final {
        const char* const input_dir;
        const char* const output_dir;
        const char* const arg_files_dir;
        const char* const hw_model;
    };

} // namespace sst::image
