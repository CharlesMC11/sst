#include "metadata.hh"

#import <Foundation/Foundation.h>

#include <chrono>
#include <format>
#include <string>

[[nodiscard]] std::string sst::image::metadata::get_timezone()
{
    const NSTimeZone* local_timezone{[NSTimeZone localTimeZone]};
    NSInteger offset_seconds{[local_timezone secondsFromGMT]};
    double offset_hours{static_cast<double>(offset_seconds) / 3600.0};

    return std::format("{}:00", offset_hours);
}

[[nodiscard]] std::string sst::image::metadata::get_os_version()
{
    const NSOperatingSystemVersion os_ver{
            [NSProcessInfo processInfo].operatingSystemVersion};

    return std::format("{}.{}.{}", os_ver.majorVersion, os_ver.minorVersion,
            os_ver.patchVersion);
}
