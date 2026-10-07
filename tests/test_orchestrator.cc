#include <dirent.h>
#include <gtest/gtest.h>
#include <sys/fcntl.h>

#include <string>
#include <vector>

#include "orchestrator.hh"
#include "processor.hh"
#include "test.hh"

TEST(SstdTest, TestCleanup)
{
    const sst::processor processor{TEST_PROCESSOR_IS_RUNNING, kMetadata};
    const int dir_fd{::open(kMetadata.input_dir, sst::kIOFlags | O_DIRECTORY)};
    ASSERT_TRUE(dir_fd != -1);

    std::vector<std::string> buffer;
    ASSERT_TRUE(sst::orchestrator::cleanup(processor, dir_fd, buffer));
    ASSERT_EQ(buffer.size(), 6UZ);
    ::close(dir_fd);
}
