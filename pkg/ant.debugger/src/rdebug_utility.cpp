#include "rdebug_lua.h"
#if defined(_WIN32)
#    include <Windows.h>
#    include <tlhelp32.h>
#endif
#include <signal.h>

namespace luadebug::utility {
#if defined(_WIN32)
    static bool closeWindow() {
        bool ok  = false;
        HANDLE h = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
        if (h != INVALID_HANDLE_VALUE) {
            THREADENTRY32 te;
            te.dwSize = sizeof(te);
            for (BOOL ok = Thread32First(h, &te); ok; ok = Thread32Next(h, &te)) {
                if (te.th32OwnerProcessID == GetCurrentProcessId()) {
                    BOOL suc = PostThreadMessageW(te.th32ThreadID, WM_QUIT, 0, 0);
                    ok       = ok || suc;
                }
            }
            CloseHandle(h);
        }
        return ok;
    }
#endif

    static int closewindow(luadbg_State* L) {
        bool ok = false;
#if defined(_WIN32)
        ok = closeWindow();
#endif
        luadbg_pushboolean(L, ok);
        return 1;
    }

    static int closeprocess(luadbg_State* L) {
        raise(SIGINT);
        return 0;
    }
    static int luaopen(luadbg_State* L) {
        luadbg_newtable(L);
        luadbgL_Reg lib[] = {
            { "closewindow", closewindow },
            { "closeprocess", closeprocess },
            { NULL, NULL }
        };
        luadbgL_setfuncs(L, lib, 0);
        return 1;
    }
}

LUADEBUG_FUNC
int luaopen_luadebug_utility(luadbg_State* L) {
    return luadebug::utility::luaopen(L);
}
