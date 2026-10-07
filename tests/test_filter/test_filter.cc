#include <fcntl.h>
#include <gtest/gtest.h>

#include "filter.hh"
#include "orchestrator.hh"

TEST(SstdTest, TestIsImage)
{
    int fd{::open(TEST_FILTER_PNG, sst::kIOFlags)};
    ASSERT_TRUE(fd != -1);
    ASSERT_TRUE(sst::filter::is_image(fd));
    ::close(fd);

    fd = ::open(TEST_FILTER_JPEG, sst::kIOFlags);
    ASSERT_TRUE(fd != -1);
    ASSERT_TRUE(sst::filter::is_image(fd));
    ::close(fd);

    fd = ::open(TEST_FILTER_TIFF1, sst::kIOFlags);
    ASSERT_TRUE(fd != -1);
    ASSERT_TRUE(sst::filter::is_image(fd));
    ::close(fd);

    fd = ::open(TEST_FILTER_TIFF2, sst::kIOFlags);
    ASSERT_TRUE(fd != -1);
    ASSERT_TRUE(sst::filter::is_image(fd));
    ::close(fd);

    fd = ::open(TEST_FILTER_HEIC1, sst::kIOFlags);
    ASSERT_TRUE(fd != -1);
    ASSERT_TRUE(sst::filter::is_image(fd));
    ::close(fd);

    fd = ::open(TEST_FILTER_HEIC2, sst::kIOFlags);
    ASSERT_TRUE(fd != -1);
    ASSERT_TRUE(sst::filter::is_image(fd));
    ::close(fd);

    fd = ::open(TEST_FILTER_LONG, sst::kIOFlags);
    ASSERT_TRUE(fd != -1);
    ASSERT_FALSE(sst::filter::is_image(fd));
    ::close(fd);

    fd = ::open(TEST_FILTER_SHORT, sst::kIOFlags);
    ASSERT_TRUE(fd != -1);
    ASSERT_FALSE(sst::filter::is_image(fd));
    ::close(fd);
}
