#pragma once
#include <string_view>

namespace sst::sorter {

/*!
 * Compare the names of two directory entries, ensuring `name 1.ext` comes
 * after `name.ext`.
 *
 * @param s1
 * An address of a directory entry
 *
 * @param s2
 * An address of a directory entry
 *
 * @result
 * `true` if `s1` is lexigraphically less than `s2`; `false` otherwise
 */
bool natural_sort(std::string_view s1, std::string_view s2);

}  // namespace sst::sorter
