#include "metadata.hh"

#import <Foundation/Foundation.h>

#include <format>
#include <string>

[[nodiscard]] const char* sst::image::metadata::os_version()
{
    static const auto result{[]() -> std::string {
        const NSOperatingSystemVersion os_ver{
                [NSProcessInfo processInfo].operatingSystemVersion};

        return std::format("{}.{}.{}", os_ver.majorVersion,
                os_ver.minorVersion, os_ver.patchVersion);
    }()};

    return result.c_str();
}

[[nodiscard]] const char* sst::image::metadata::timezone()
{
    static const auto result{[]() -> std::string {
        const NSTimeZone* local_timezone{[NSTimeZone localTimeZone]};
        const long offset_seconds{[local_timezone secondsFromGMT]};
        const long offset_hours{offset_seconds / 3600L};

        return std::format("{:03d}00", offset_hours);
    }()};

    return result.c_str();
}
