#pragma once

#include <fcntl.h>

#include "exiftool_args.hh"
#include "orchestrator.hh"

// FIXME: Actually make this work
class sst_test : public ::testing::Test {
protected:
    sst::exiftool_args* argv{nullptr};

    void SetUp() override
    {
        const int fd{::open(
                TEST_ORCHESTRATOR_CLEANUP, sst::kIOFlags | O_DIRECTORY)};
        ASSERT_NE(fd, -1);

        static sst::exiftool_args args{
                fd, TEST_ORCHESTRATOR_CLEANUP, "out_dir", "args_dir"};
        argv = &args;
    }

    void TearDown() override { close(argv->input_dir_fd); }
};
