#include <gtest/gtest.h>

#include <fstream>
#include <limits>
#include <system_error>

#include "metadata.hh"
#include "processor.hh"
#include "test.hh"

TEST(SstdTest, TestConstructorFail)
{
    ASSERT_THROW(sst::processor("prog", kMetadata), std::system_error);
}

TEST(SstdTest, TestIsRunning)
{
    const sst::processor processor{TEST_PROCESSOR_IS_RUNNING, kMetadata};
    ASSERT_TRUE(processor.is_running());
}

TEST(SstdTest, TestSendFilenames)
{
    {
        sst::processor processor{TEST_PROCESSOR_SEND, kMetadata};
        ASSERT_TRUE(processor.send_to_exiftool(""));
        ASSERT_TRUE(processor.send_to_exiftool("Hello\nWorld!\n"));
    }

    std::ifstream infile{TEST_PROCESSOR_SEND_FILE};
    ASSERT_TRUE(infile.good());

    std::string line;
    std::getline(infile, line);
    ASSERT_TRUE(line.contains("Hello"));

    std::getline(infile, line);
    ASSERT_TRUE(line.contains("World!"));

    std::getline(infile, line);
    ASSERT_TRUE(line.contains("-execute"));

    std::getline(infile, line);
    ASSERT_TRUE(line.contains("-stay_open"));

    std::getline(infile, line);
    ASSERT_TRUE(line.contains("False"));
}

TEST(SstdTest, TestResend)
{
    sst::processor processor{TEST_PROCESSOR_IS_RUNNING, kMetadata, 3Z};

    char long_string[PATH_MAX];
    std::fill(std::begin(long_string), std::end(long_string), '?');

    ASSERT_TRUE(processor.send_to_exiftool(long_string));
}
