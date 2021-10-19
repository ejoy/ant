#include "path_helper.h"

#include <Foundation/Foundation.h>
#include <sys/stat.h>
#include <sys/types.h>

namespace ant::path_helper {
    fs::path appdata_path() {
        NSArray *array = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        if ([array count] > 0) {
            return fs::path([[array objectAtIndex:0] fileSystemRepresentation]);
        }
        throw std::runtime_error("NSSearchPathForDirectoriesInDomains failed.");
    }
}
