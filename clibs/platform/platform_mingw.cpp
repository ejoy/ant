#include <lua.hpp>
#include <windows.h>
#include <string>
#include <string_view>
#include <memory>
#include <algorithm>
#include "win32/wmi.h"

#if !defined(__MINGW32__)
#include <shellscalingapi.h>
#else
enum MONITOR_DPI_TYPE {
    MDT_EFFECTIVE_DPI,
    MDT_ANGULAR_DPI,
    MDT_RAW_DPI,
    MDT_DEFAULT
};
enum PROCESS_DPI_AWARENESS {
  PROCESS_DPI_UNAWARE,
  PROCESS_SYSTEM_DPI_AWARE,
  PROCESS_PER_MONITOR_DPI_AWARE
};
#endif

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

struct shcore {
    bool init();
    bool isValid() const { return getProcessDpiAwareness && setProcessDpiAwareness && getDpiForMonitor; }
    typedef HRESULT (WINAPI *GetProcessDpiAwareness)(HANDLE,PROCESS_DPI_AWARENESS *);
    typedef HRESULT (WINAPI *SetProcessDpiAwareness)(PROCESS_DPI_AWARENESS);
    typedef HRESULT (WINAPI *GetDpiForMonitor)(HMONITOR,MONITOR_DPI_TYPE,UINT *,UINT *);
    GetProcessDpiAwareness getProcessDpiAwareness = nullptr;
    SetProcessDpiAwareness setProcessDpiAwareness = nullptr;
    GetDpiForMonitor getDpiForMonitor = nullptr;
};

bool shcore::init() {
    if (isValid()) {
        return true;
    }
    HMODULE dll = LoadLibraryW(L"SHCore.dll");
    if (!dll) {
        return false;
    }
    getProcessDpiAwareness = (GetProcessDpiAwareness)GetProcAddress(dll, "GetProcessDpiAwareness");
    setProcessDpiAwareness = (SetProcessDpiAwareness)GetProcAddress(dll, "SetProcessDpiAwareness");
    getDpiForMonitor = (GetDpiForMonitor)GetProcAddress(dll, "GetDpiForMonitor");
    return isValid();
}

shcore shcore;

int linit_dpi(lua_State* L) {
    const char* mode = luaL_checkstring(L, 1);
    if (!shcore.init()) {
        lua_pushboolean(L, 0);
        return 1;
    }
    PROCESS_DPI_AWARENESS aware = PROCESS_DPI_UNAWARE;
    if (mode[0] == 'p') {
        aware = PROCESS_PER_MONITOR_DPI_AWARE;
    }
    else if (mode[0] == 's') {
        aware = PROCESS_SYSTEM_DPI_AWARE;
    }
    if (S_OK != shcore.setProcessDpiAwareness(aware)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    lua_pushboolean(L, 1);
    return 1;
}

int ldpi(lua_State* L) {
    HWND window = (lua_type(L, 1) == LUA_TLIGHTUSERDATA)
        ? (HWND)lua_touserdata(L, 1)
        : GetDesktopWindow()
        ;
    if (!shcore.init()) {
        return 0;
    }
    UINT xdpi = 0;
    UINT ydpi = 0;
    if (S_OK != shcore.getDpiForMonitor(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST), MDT_EFFECTIVE_DPI, &xdpi, &ydpi)) {
        return 0;
    }
    lua_pushinteger(L, xdpi);
    lua_pushinteger(L, ydpi);
    return 2;
}

int lfont(lua_State* L) {
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
            void* table = lua_newuserdatauv(L, bytes + 4, 0);
            bytes = GetFontData(hdc, tag, 0, (unsigned char*)table+4, bytes);
            if (bytes != GDI_ERROR) {
                *(uint32_t*)table = (uint32_t)bytes;
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

int linfo(lua_State* L) {
    const char* lst[] = {"memory", NULL};
    int opt = luaL_checkoption(L, 1, NULL, lst);
    switch (opt) {
    case 0: {
        static wmi wmi;
        if (!wmi) {
            return luaL_error(L, "WMI initialize failed");
        }
        static std::wstring query = L"SELECT WorkingSetPrivate FROM Win32_PerfRawData_PerfProc_Process WHERE IDProcess=" + std::to_wstring(GetCurrentProcessId());
        auto process_object = wmi.query(query);
        if (!process_object) {
            return luaL_error(L, "WMI query failed");
        }
        std::wstring memory = process_object.get_string(L"WorkingSetPrivate");
        lua_pushinteger(L, (lua_Integer)std::stoll(memory));
        return 1;
    }
    default:
        return luaL_error(L, "invalid option");
    }
}
