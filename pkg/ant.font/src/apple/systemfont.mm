#include <lua.hpp>
#include <Foundation/Foundation.h>
#include <CoreText/CoreText.h>
#include "memfile.h"

static int systemfont(lua_State* L) {
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
    auto file = memory_file_alloc(len);
    fread((void*)file->data, file->sz, 1, f);
    fclose(f);
    lua_pushlightuserdata(L, file);
    return 1;
}

extern "C"
int luaopen_font_util(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "systemfont", systemfont },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
