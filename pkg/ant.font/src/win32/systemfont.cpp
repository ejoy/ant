#include <lua.hpp>
#include <windows.h>
#include <string>
#include <string_view>
#include <memory>
#include "memfile.h"

#include <bee/win/wtf8.h>

static std::wstring towstring(lua_State* L, int idx) {
    size_t len = 0;
    const char* str = luaL_checklstring(L, idx, &len);
    return bee::wtf8::u2w(bee::zstring_view(str, len));
}

static int systemfont(lua_State* L) {
    auto familyName = towstring(L, 1);
    HDC hdc = CreateCompatibleDC(0);
    LOGFONTW lf;
    memset(&lf, 0, sizeof(LOGFONT));
    memcpy(lf.lfFaceName, familyName.c_str(), (std::min)((size_t)LF_FACESIZE, familyName.size()) * sizeof(wchar_t));
    lf.lfCharSet = DEFAULT_CHARSET;
    HFONT hfont = CreateFontIndirectW(&lf); 
    if (!hfont) {
        DeleteDC(hdc);
        return luaL_error(L, "Create font failed: %d", GetLastError());
    }
    memory_file* file = nullptr;
    bool ok = false;
    HGDIOBJ oldobj = SelectObject(hdc, hfont);
    for (uint32_t tag : {0x66637474/*ttcf*/, 0}) {
        DWORD bytes = GetFontData(hdc, tag, 0, 0, 0);
        if (bytes != GDI_ERROR) {
            file = memory_file_alloc(bytes);
            bytes = GetFontData(hdc, tag, 0, (unsigned char*)file->data, (DWORD)file->sz);
            if (bytes != GDI_ERROR) {
                ok = true;
                break;
            }
        }
    }
    SelectObject(hdc, oldobj);
    DeleteObject(hfont);
    DeleteDC(hdc);
    if (!ok) {
        memory_file_close(file);
        return luaL_error(L, "Read font data failed");
    }
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
