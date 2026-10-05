#include "sorter.hh"

#include <CoreFoundation/CoreFoundation.h>

#include <iostream>
#include <string>
#include <vector>

// FIXME: Reimplement in C++; maybe use Arm Neon?
void sst::sorter::natural_sort(std::vector<std::string>& list)
{
    // CFArraySortValues(
    //         list, CFRangeMake(0, CFArrayGetCount(list)),
    //         [](const void* a, const void* b, void*) {
    //             const auto url_a{static_cast<CFURLRef>(a)};
    //             const auto url_b{static_cast<CFURLRef>(b)};

    //             return CFStringCompare(CFURLGetString(url_a),
    //                     CFURLGetString(url_b),
    //                     kCFCompareCaseInsensitive |
    //                             kCFCompareDiacriticInsensitive |
    //                             kCFCompareLocalized |
    //                             kCFCompareNumerically);
    //         },
    //         nullptr);
}

void sst::sorter::print_sorted(std::vector<std::string>& list)
{
    if (list.empty()) [[unlikely]] {
        return;
    }

    sst::sorter::natural_sort(list);

    std::cout << "[sstd::sorter] Printing buffer contents:\n";
    for (const auto& path: list) {
        std::cout << path << '\n';
    }
    std::cout << std::flush;
}
