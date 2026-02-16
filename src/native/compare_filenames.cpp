#include "compare_filenames.hpp"

#include <algorithm>
#include <charconv>
#include <string_view>

bool compare_filenames(std::string_view s1, std::string_view s2) {
  const auto [it1,
              it2]{std::mismatch(s1.begin(), s1.end(), s2.begin(), s2.end())};
  if (it1 == s1.end() && it2 == s2.end()) return false;

  s1.remove_prefix(std::distance(s1.begin(), it1));
  s2.remove_prefix(std::distance(s2.begin(), it2));
  while (!s1.empty() && !s2.empty()) {
    if ((s1[0] == '.' && s2[0] == ' ') || (s1[0] == ' ' && s2[0] == '.'))
      return s1[0] == '.';

    if (std::isdigit(static_cast<unsigned char>(s1[0])) &&
        std::isdigit(static_cast<unsigned char>(s2[0]))) {
      unsigned long n1, n2;

      auto [ptr1, ec1]{std::from_chars(s1.data(), s1.data() + s1.length(), n1)};
      auto [ptr2, ec2]{std::from_chars(s2.data(), s2.data() + s2.length(), n2)};
      if (n1 != n2) return n1 < n2;

      const auto len1{ptr1 - s1.data()};
      const auto len2{ptr2 - s2.data()};

      s1.remove_prefix(len1);
      s2.remove_prefix(len2);
    } else {
      char c1 = std::tolower(static_cast<unsigned char>(s1[0]));
      char c2 = std::tolower(static_cast<unsigned char>(s2[0]));
      if (c1 != c2) return c1 < c2;

      s1.remove_prefix(1);
      s2.remove_prefix(1);
    }
  }

  if (s1.empty() && s2.empty()) return false;
  return s1.empty();
}
