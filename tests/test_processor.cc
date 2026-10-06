#include <gtest/gtest.h>

#include <fstream>
#include <system_error>

#include "metadata.hh"
#include "processor.hh"

static const sst::image::metadata kMetadata{"in_dir", "out_dir", "args_dir", "model", "os"};

TEST(SstdTest, TestConstructorFail)
{
    ASSERT_THROW(sst::processor("prog", kMetadata), std::system_error);
}

TEST(SstdTest, TestIsRunning)
{
    const sst::processor processor{TEST_PROCESSOR_IS_RUNNING, kMetadata};
    ASSERT_TRUE(processor.is_running());
}

TEST(SsstdTest, TestSend)
{
    {
        const sst::processor processor{TEST_PROCESSOR_SEND, kMetadata};
        processor.send_filenames({"Hello", "World!"});
    }

    std::ifstream infile{TEST_PROCESSOR_SEND_FILE};
    ASSERT_TRUE(infile.good());

    std::string line;
    std::getline(infile, line);
    ASSERT_TRUE(line.contains("in_dir/Hello in_dir/World!"));

    std::getline(infile, line);
    ASSERT_TRUE(line.contains("-execute"));

    std::getline(infile, line);
    ASSERT_TRUE(line.contains("-stay_open"));

    std::getline(infile, line);
    ASSERT_TRUE(line.contains("False"));
}
