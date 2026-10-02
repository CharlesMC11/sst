#ifndef SST__SORTER__HH
#define SST__SORTER__HH

#include <CoreFoundation/CFArray.h>

namespace sst::sorter {

    void natural_sort(CFMutableArrayRef list);

    void print_sorted(CFMutableArrayRef list);

} // namespace sst::sorter

#endif // SST__SORTER__HH
