#include <lua.hpp>
#include <Cocoa/Cocoa.h>

int ldpi(lua_State* L) {
    NSWindow* window = (lua_type(L, 1) == LUA_TLIGHTUSERDATA)
        ? (NSWindow*)lua_touserdata(L, 1)
        : 0
        ;
    NSScreen *screen = window? [window screen]: [NSScreen mainScreen];
    NSDictionary *description = [screen deviceDescription]; 
    NSSize displayPixelSize = [[description objectForKey:NSDeviceSize] sizeValue];
    CGSize displayPhysicalSize = CGDisplayScreenSize( [[description objectForKey:@"NSScreenNumber"] unsignedIntValue]);
    lua_pushinteger(L, (displayPixelSize.width / displayPhysicalSize.width) * 25.4f);
    lua_pushinteger(L, (displayPixelSize.height / displayPhysicalSize.height) * 25.4f);
    return 2;
}
