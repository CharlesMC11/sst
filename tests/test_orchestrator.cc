#include <dirent.h>
#include <gtest/gtest.h>
#include <sys/fcntl.h>

#include <bit>
#include <string>

#include "orchestrator.hh"
#include "processor.hh"
#include "test.hh"

TEST(SstdTest, TestCleanup)
{
    sst::processor processor{TEST_PROCESSOR_IS_RUNNING, kMetadata};

    std::string_view input_dir{TEST_ORCHESTRATOR_CLEANUP};

    const int dir_fd{::open(input_dir.data(), sst::kIOFlags | O_DIRECTORY)};
    ASSERT_TRUE(dir_fd != -1);

    const std::size_t min_buffer_size{input_dir.length() + 2UZ};
    const std::size_t buffer_size{
            std::bit_ceil((min_buffer_size + 45UZ) * 6UZ)};
    std::string buffer;
    buffer.reserve(buffer_size);

    sst::orchestrator orchestrator{
            processor, input_dir.data(), dir_fd, buffer};

    ASSERT_TRUE(orchestrator.cleanup());
    ASSERT_EQ(buffer.length(), min_buffer_size * 6UZ + 51UZ);
    ::close(dir_fd);
}
