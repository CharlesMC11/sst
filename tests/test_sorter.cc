#include <gtest/gtest.h>

#include <string>
#include <vector>

#include "sorter.hh"

TEST(SstdTest, TestNaturalSort)
{
    constexpr auto a{"Screenshot 1.png"};
    constexpr auto b{"Screenshot 10.png"};
    constexpr auto c{"Screenshot 10 (1).png"};

    std::vector<std::string> buffer{c, b, a};
    sst::sorter::natural_sort(buffer);

    ASSERT_EQ(buffer[0], a);
    ASSERT_EQ(buffer[1], c);
    ASSERT_EQ(buffer[2], b);
}
