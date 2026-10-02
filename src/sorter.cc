#include "sorter.hh"

#include <CoreFoundation/CoreFoundation.h>

#include <iostream>

namespace sst::sorter {

    void natural_sort(CFMutableArrayRef list)
    {
        CFArraySortValues(
                list, CFRangeMake(0, CFArrayGetCount(list)),
                [](const void* a, const void* b, void*) {
                    const auto url_a{static_cast<CFURLRef>(a)};
                    const auto url_b{static_cast<CFURLRef>(b)};

                    return CFStringCompare(CFURLGetString(url_a),
                            CFURLGetString(url_b),
                            kCFCompareCaseInsensitive |
                                    kCFCompareDiacriticInsensitive |
                                    kCFCompareLocalized |
                                    kCFCompareNumerically);
                },
                nullptr);
    }

    void print_sorted(CFMutableArrayRef list)
    {
        if (!list) [[unlikely]] {
            return;
        }

        const CFIndex count{CFArrayGetCount(list)};
        if (count == 0Z) [[unlikely]] {
            return;
        }

        natural_sort(list);

        std::cout << "[sstd] Printing buffer contents:\n";
        for (CFIndex i{0Z}; i < count; ++i) {
            const auto url{
                    static_cast<CFURLRef>(CFArrayGetValueAtIndex(list, i))};

            char path[PATH_MAX];
            if (CFURLGetFileSystemRepresentation(url, true,
                        reinterpret_cast<UInt8*>(path), sizeof(path)))
                    [[likely]] {
                std::cout << path << '\n';
            }
        }
        std::cout << std::flush;
    }

} // namespace sst::sorter
