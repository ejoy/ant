#include <lua.hpp>
#include <windows.h>
#include <string>
#include <string_view>
#include <memory>

static std::wstring u2w(const std::string_view& str) {
    if (str.empty()) {
        return L"";
    }
    int wlen = ::MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), NULL, 0);
    if (wlen <= 0)  {
        return L"";
    }
    std::unique_ptr<wchar_t[]> result(new wchar_t[wlen]);
    ::MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), result.get(), wlen);
    return std::wstring(result.release(), wlen);
}

static std::wstring towstring(lua_State* L, int idx) {
    size_t len = 0;
    const char* str = luaL_checklstring(L, idx, &len);
    return u2w(std::string_view(str, len));
}

int ImGuiSystemFont(lua_State* L) {
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
    bool ok = false;
    HGDIOBJ oldobj = SelectObject(hdc, hfont);
    for (uint32_t tag : {0x66637474/*ttcf*/, 0}) {
        DWORD bytes = GetFontData(hdc, tag, 0, 0, 0);
        if (bytes != GDI_ERROR) {
            void* table = lua_newuserdatauv(L, bytes, 0);
            bytes = GetFontData(hdc, tag, 0, (unsigned char*)table, bytes);
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
        return luaL_error(L, "Read font data failed");
    }
    return 1;
}
