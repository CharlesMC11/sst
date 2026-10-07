#include <fcntl.h>
#include <gtest/gtest.h>

#include "filter.hh"

TEST(SstdTest, TestIsImage)
{
    int fd{::open(TEST_FILTER_PNG, O_RDONLY)};
    ASSERT_TRUE(fd != -1);
    ASSERT_TRUE(sst::filter::is_image(fd));
    ::close(fd);

    fd = ::open(TEST_FILTER_JPEG, O_RDONLY);
    ASSERT_TRUE(fd != -1);
    ASSERT_TRUE(sst::filter::is_image(fd));
    ::close(fd);

    fd = ::open(TEST_FILTER_TIFF1, O_RDONLY);
    ASSERT_TRUE(fd != -1);
    ASSERT_TRUE(sst::filter::is_image(fd));
    ::close(fd);

    fd = ::open(TEST_FILTER_TIFF2, O_RDONLY);
    ASSERT_TRUE(fd != -1);
    ASSERT_TRUE(sst::filter::is_image(fd));
    ::close(fd);

    fd = ::open(TEST_FILTER_HEIC1, O_RDONLY);
    ASSERT_TRUE(fd != -1);
    ASSERT_TRUE(sst::filter::is_image(fd));
    ::close(fd);

    fd = ::open(TEST_FILTER_HEIC2, O_RDONLY);
    ASSERT_TRUE(fd != -1);
    ASSERT_TRUE(sst::filter::is_image(fd));
    ::close(fd);

    fd = ::open(TEST_FILTER_LONG, O_RDONLY);
    ASSERT_TRUE(fd != -1);
    ASSERT_FALSE(sst::filter::is_image(fd));
    ::close(fd);

    fd = ::open(TEST_FILTER_SHORT, O_RDONLY);
    ASSERT_TRUE(fd != -1);
    ASSERT_FALSE(sst::filter::is_image(fd));
    ::close(fd);
}
