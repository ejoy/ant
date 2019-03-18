#include <lua.hpp>
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
