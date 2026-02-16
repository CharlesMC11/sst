#pragma once
#include <string_view>

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
bool compare_filenames(std::string_view s1, std::string_view s2);
