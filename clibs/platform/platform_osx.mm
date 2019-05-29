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

int lfont(lua_State* L) {
    const char* familyName = luaL_checkstring(L, 1);
    CTFontDescriptorRef fontRef = CTFontDescriptorCreateWithNameAndSize(CFStringCreateWithCString(NULL, familyName, kCFStringEncodingUTF8), 0.0);
    CFURLRef url = (CFURLRef)CTFontDescriptorCopyAttribute(fontRef, kCTFontURLAttribute);
    const char * fontpath = [[(NSURL *)CFBridgingRelease(url) path] UTF8String];
    FILE* f = fopen(fontpath, "rb");
    if (!f) {
        return luaL_error(L, "open `%s` failed.", fontpath);
    }
    fseek(f, 0, SEEK_END);
    size_t len = (size_t)ftell(f);
    fseek(f, 0, SEEK_SET);
    void* buffer = lua_newuserdata(L, len);
    fread(buffer, len, 1, f);
    fclose(f);
    lua_pushlstring(L, (const char*)buffer, len);
    return 1;
}
