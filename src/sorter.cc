#include "sorter.hh"

#include <CoreFoundation/CoreFoundation.h>

#include <algorithm>
#include <string>
#include <vector>

#include "memory.hh"

// FIXME: Lots of heap allocation going on here
void sst::sorter::natural_sort(std::vector<std::string>& list)
{
    std::ranges::sort(list.begin(), list.end(),
            [](const std::string& a, const std::string& b) -> bool {
                const sst::memory::cf_ptr<CFStringRef> a_cstr{
                        ::CFStringCreateWithCString(
                                nullptr, a.c_str(), ::kCFStringEncodingUTF8)};
                const sst::memory::cf_ptr<CFStringRef> b_cstr{
                        ::CFStringCreateWithCString(
                                nullptr, b.c_str(), ::kCFStringEncodingUTF8)};

                return ::CFStringCompare(a_cstr.get(), b_cstr.get(),
                               ::kCFCompareCaseInsensitive |
                                       ::kCFCompareDiacriticInsensitive |
                                       ::kCFCompareLocalized |
                                       kCFCompareNumerically) ==
                        ::kCFCompareLessThan;
            });
}
