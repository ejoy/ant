#if defined(_WIN32)
#define _WIN32_WINNT _WIN32_WINNT_WINBLUE
#endif

#include <lua.hpp>
#include <bx/platform.h>

#if defined(_WIN32)
#include <windows.h>
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
#else
int ldpi(lua_State* L) {
    // TODO
    return 0;
}
#endif

extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int luaopen_platform(lua_State* L) {
    static luaL_Reg lib[] = {
#if defined(_WIN32)
        { "init_dpi", linit_dpi },
#endif
        { "dpi", ldpi },
        { NULL, NULL },
    };
    luaL_newlib(L, lib);
    lua_pushstring(L, BX_PLATFORM_NAME);
    lua_setfield(L, -2, "OS");
    lua_pushstring(L, BX_CRT_NAME);
    lua_setfield(L, -2, "CRT");
    return 1;
}
