#include "metadata.hh"

#import <Foundation/Foundation.h>

#include <string>

[[nodiscard]] std::string sst::image::metadata::get_os_version()
{
    const NSOperatingSystemVersion os_ver{
            [NSProcessInfo processInfo].operatingSystemVersion};

    return std::format("{}.{}.{}", os_ver.majorVersion, os_ver.minorVersion,
            os_ver.patchVersion);
}
