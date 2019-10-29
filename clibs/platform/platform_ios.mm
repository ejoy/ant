#import <UIKit/UIKit.h>
#include <lua.hpp>
#include <sys/utsname.h>
#include <sys/sysctl.h>
#include <map>
#include <vector>
#include <string>

static std::map<std::vector<std::string>, int> iosdevs = {
    {
        {
            // iPhone XS
            "iPhone11,2",
            // iPhone XS Max
            "iPhone11,4", "iPhone11,6",
            // iPhone X
            "iPhone10,3", "iPhone10,6"
        },
        458
    },
    {
        {
            // iPhone 8 Plus
            "iPhone10,2", "iPhone10,5",
            // iPhone 7 Plus
            "iPhone9,2", "iPhone9,4",
            // iPhone 6S Plus
            "iPhone8,2",
            // iPhone 6 Plus
            "iPhone7,1"
        },
        401
    },
    {
        {
            // iPhone XR
            "iPhone11,8",
            // iPhone 8
            "iPhone10,1", "iPhone10,4",
            // iPhone 7
            "iPhone9,1", "iPhone9,3",
            // iPhone 6S
            "iPhone8,1",
            // iPhone 6
            "iPhone7,2",
            // iPhone SE
            "iPhone8,4",
            // iPhone 5S
            "iPhone6,1", "iPhone6,2",
            // iPhone 5C
            "iPhone5,3", "iPhone5,4",
            // iPhone 5
            "iPhone5,1", "iPhone5,2",
            // iPod Touch {6th generation}
            "iPod7,1",
            // iPod Touch {5th generation}
            "iPod5,1",
            // iPhone 4S
            "iPhone4,1",
            // iPad Mini 4
            "iPad5,1", "iPad5,2",
            // iPad Mini 3
            "iPad4,7", "iPad4,8", "iPad4,9",
            // iPad Mini 2
            "iPad4,4", "iPad4,5", "iPad4,6"
        },
        326
    },
    {
        {
            // iPad Pro {12.9″, 3rd generation}
            "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8",
            // iPad Pro {11″}
            "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4",
            // iPad {6th generation}
            "iPad7,5", "iPad7,6",
            // iPad Pro {10.5″}
            "iPad7,3", "iPad7,4",
            // iPad Pro {12.9″, 2nd generation}
            "iPad7,1", "iPad7,2",
            // iPad {5th generation}
            "iPad6,11", "iPad6,12",
            // iPad Pro {12.9″}
            "iPad6,7", "iPad6,8",
            // iPad Pro {9.7″}
            "iPad6,3", "iPad6,4",
            // iPad Air 2
            "iPad5,3", "iPad5,4",
            // iPad Air
            "iPad4,1", "iPad4,2", "iPad4,3",
            // iPad {4th generation}
            "iPad3,4", "iPad3,5", "iPad3,6",
            // iPad {3rd generation}
            "iPad3,1", "iPad3,2", "iPad3,3"
        },
        264
    },
    {
        {
            // iPad Mini
            "iPad2,5", "iPad2,6", "iPad2,7"
        },
        163
    },
    {
        {
            // iPad 2
            "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4"
        },
        132
    }
};

static std::map<std::string, int> init() {
    std::map<std::string, int> m;
    for (auto devs : iosdevs) {
        for (auto dev : devs.first) {
            m.insert(std::make_pair(dev, devs.second));
        }
    }
    return m;
}

std::map<std::string, int> iosppi = init();

static int guess() {
    float scale = 1;
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
        scale = [[UIScreen mainScreen] scale];
    }
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return scale == 2 ? 264 : 132;
    }
    if (scale == 3) {
        return [[UIScreen mainScreen] nativeScale] == 3 ? 458 : 401;
    }
    return 326;
}

int ldpi(lua_State* L) {
    struct utsname systemInfo;
    if (uname(&systemInfo) < 0) {
        int dpi = guess();
        lua_pushinteger(L, dpi);
        lua_pushinteger(L, dpi);
        return 2;
    }
    auto it = iosppi.find(systemInfo.machine);
    if (it == iosppi.end()) {
        int dpi = guess();
        lua_pushinteger(L, dpi);
        lua_pushinteger(L, dpi);
        return 2;
    }
    lua_pushinteger(L, it->second);
    lua_pushinteger(L, it->second);
    return 2;
}

int lmachine(lua_State* L) {
    char value[256];
    size_t len = 256;
    if (sysctlbyname("hw.machine", &value, &len, nullptr, 0) == 0) {
        assert(len > 1);
        assert(value[len - 1] == '\0');
        lua_pushlstring(L, value, len - 1);
        return 1;
    }
    return 0;
}
