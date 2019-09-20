#include <lua.hpp>
#include <Foundation/Foundation.h>
#include <CoreText/CoreText.h>

int lfont(lua_State* L) {
    const char* familyName = luaL_checkstring(L, 1);
    CTFontDescriptorRef fontRef = CTFontDescriptorCreateWithNameAndSize(CFStringCreateWithCString(NULL, familyName, kCFStringEncodingUTF8), 0.0);
    CFURLRef url = (CFURLRef)CTFontDescriptorCopyAttribute(fontRef, kCTFontURLAttribute);
    const char * fontpath = [[(NSURL *)CFBridgingRelease(url) path] UTF8String];
    CFRelease(fontRef);
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
