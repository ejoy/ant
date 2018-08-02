#include <lua.hpp>
#include <thread>

#if defined(_WIN32)

#include <Windows.h>
#include <io.h>
#include <fcntl.h>
#include "msgqueue.h"

struct thread_args {
    HANDLE file;
    msgqueue queue;
    bool closed = false;
    thread_args(HANDLE f)
        : file(f)
        , queue()
    { }
    ~thread_args() {
        CloseHandle(file);
    }
};

static DWORD WINAPI async_stdin_thread(LPVOID lpParam) {
    thread_args* ta = (thread_args*)lpParam;
    HANDLE f = ta->file;
    char tmp[1024];
    DWORD sz;
    while (ReadFile(f, tmp, sizeof(tmp), &sz, NULL)) {
        if (sz != 0) {
            ta->queue.push(tmp, sz);
        }
    }
    ta->queue.push(0, 0);
    return 0;
}

static int as_read(lua_State* L) {
    thread_args* ta = (thread_args*)lua_touserdata(L, lua_upvalueindex(1));
    if (ta->closed) {
        lua_pushboolean(L, false);
        return 1;
    }
    msgqueue::autodelete_msg msg;
    if (!ta->queue.try_pop(msg)) {
        lua_pushboolean(L, true);
        return 1;
    }
    if (!msg.str) {
        ta->closed = true;
        lua_pushboolean(L, false);
        return 1;
    }
    lua_pushboolean(L, true);
    lua_pushlstring(L, msg.str, msg.len);
    return 2;
}

static int async_stdin(lua_State* L) {
    HANDLE f = GetStdHandle(STD_INPUT_HANDLE);
    thread_args* ta = new thread_args(f);
    CreateThread(NULL, 4096, async_stdin_thread, (LPVOID)ta, 0, NULL);
    static luaL_Reg lib[] = {
        { "read", as_read },
        { NULL, NULL },
    };
    lua_newtable(L);
    lua_pushlightuserdata(L, ta);
    luaL_setfuncs(L, lib, 1);
    return 1;
}

static int filemode(lua_State* L) {
    luaL_Stream* p =  ((luaL_Stream*)luaL_checkudata(L, 1, LUA_FILEHANDLE));
    const char* mode = luaL_checkstring(L, 2);
    if (p && p->f) {
        if (mode[0] == 'b') {
            _setmode(_fileno(p->f), _O_BINARY);
        }
        else if (mode[0] == 't') {
            _setmode(_fileno(p->f), _O_TEXT);
        }
    }
    return 0;
}

#endif

static int os(lua_State* L) {
#if defined(_WIN32)
    lua_pushstring(L, "windows");
#else
    lua_pushstring(L, "unknown");
#endif
    return 1;
}

static int sleep(lua_State* L) {
    std::this_thread::sleep_for(std::chrono::milliseconds((int)luaL_checkinteger(L, 1)));
    return 0;
}

extern "C" 
#if defined(_WIN32)
__declspec(dllexport)
#endif
int luaopen_debugger_frontend(lua_State* L) {
    static luaL_Reg lib[] = {
        { "os", os },
        { "sleep", sleep },
#if defined(_WIN32)
        { "filemode", filemode },
        { "async_stdin", async_stdin },
#endif
        { NULL, NULL },
    };    
    lua_newtable(L);
    luaL_setfuncs(L, lib, 0);
    return 1;
}
