#include "subprocess.h"
#include <lua.hpp>
#include <optional>
#include <errno.h>
#include <string.h>

#if defined(_WIN32)

typedef std::wstring nativestring;

std::wstring u2w(const char* str, size_t len) {
	int wlen = ::MultiByteToWideChar(CP_UTF8, 0, str, len, NULL, 0);
	if (wlen <= 0) {
		return L"";
	}
	std::dynarray<wchar_t> result(wlen);
	::MultiByteToWideChar(CP_UTF8, 0, str, len, result.data(), wlen);
	return std::wstring(result.data(), result.size());
}

std::wstring luaL_checknativestring(lua_State* L, int idx) {
    size_t len = 0;
    const char* str = luaL_checklstring(L, idx, &len);
    return u2w(str, len);
}

#else

typedef std::string nativestring;

std::string luaL_checknativestring(lua_State* L, int idx) {
    size_t len = 0;
    const char* str = luaL_checklstring(L, idx, &len);
    return std::string(str, len);
}

#endif

namespace process {
    static int constructor(lua_State* L, base::subprocess::spawn& spawn) {
        void* storage = lua_newuserdata(L, sizeof(base::subprocess::process));
        luaL_getmetatable(L, "subprocess");
        lua_setmetatable(L, -2);
        new (storage)base::subprocess::process(spawn);
        return 1;
    }

    static base::subprocess::process& to(lua_State* L, int idx) {
        return *(base::subprocess::process*)luaL_checkudata(L, idx, "subprocess");
    }

    static int destructor(lua_State* L) {
        base::subprocess::process& self = to(L, 1);
        self.~process();
        return 0;
    }

    static int wait(lua_State* L) {
        base::subprocess::process& self = to(L, 1);
        lua_pushinteger(L, (lua_Integer)self.wait());
        return 1;
    }

    static int kill(lua_State* L) {
        base::subprocess::process& self = to(L, 1);
        bool ok = self.kill(5000);
        lua_pushboolean(L, ok);
        return 1;
    }

    static int get_id(lua_State* L) {
        base::subprocess::process& self = to(L, 1);
        lua_pushinteger(L, (lua_Integer)self.get_id());
        return 1;
    }

    static int is_running(lua_State* L) {
        base::subprocess::process& self = to(L, 1);
        lua_pushboolean(L, self.is_running());
        return 1;
    }
}

namespace spawn {
    static std::optional<nativestring> cast_cwd(lua_State* L) {
        if (LUA_TSTRING == lua_getfield(L, 1, "cwd")) {
            nativestring ret(luaL_checknativestring(L, -1));
            lua_pop(L, 1);
            return ret;
        }
        lua_pop(L, 1);
        return std::optional<nativestring>();
    }

    static int fileclose(lua_State* L) {
        luaL_Stream* p = (luaL_Stream*)luaL_checkudata(L, 1, LUA_FILEHANDLE);
        int ok = fclose(p->f);
        int en = errno;  /* calls to Lua API may change this value */
        if (ok) {
            lua_pushboolean(L, 1);
            return 1;
        }
        else {
            lua_pushnil(L);
            lua_pushfstring(L, "%s", strerror(en));
            lua_pushinteger(L, en);
            return 3;
        }
    }

    static int newfile(lua_State* L, FILE* f) {
        luaL_Stream* pf = (luaL_Stream*)lua_newuserdata(L, sizeof(luaL_Stream));
        luaL_setmetatable(L, LUA_FILEHANDLE);
        pf->closef = &fileclose;
        pf->f = f;
        return 1;
    }

#if defined(_WIN32)
    typedef std::dynarray<nativestring> native_args;
#   define LOAD_ARGS(L, idx) luaL_checknativestring((L), (idx))
#else
    typedef std::dynarray<char*> native_args;
#   define LOAD_ARGS(L, idx) (char*)luaL_checkstring((L), (idx))
#endif
    static native_args cast_args(lua_State* L) {
        size_t n = (size_t)luaL_len(L, 1);
        native_args args(n + 1);
        for (size_t i = 0; i < n; ++i) {
            lua_geti(L, 1, i + 1);
            args[i] = LOAD_ARGS(L, -1);
            lua_pop(L, 1);
        }
        args[n] = native_args::value_type();
        return args;
    }

    static FILE* cast_stdio(lua_State* L, const char* name) {
        switch (lua_getfield(L, 1, name)) {
        case LUA_TUSERDATA: {
            luaL_Stream* p = (luaL_Stream*)luaL_checkudata(L, -1, LUA_FILEHANDLE);
            return p->f;
        }
        case LUA_TBOOLEAN: {
            if (!lua_toboolean(L, -1)) {
                break;
            }
            auto[rd, wr] = base::subprocess::pipe::open();
            if (!rd || !wr) {
                break;
            }
            lua_pop(L, 1);
            if (strcmp(name, "stdin") == 0) {
                newfile(L, wr);
                return rd;
            }
            else {
                newfile(L, rd);
                return wr;
            }
        }
        default:
            break;
        }
        lua_pop(L, 1);
        return nullptr;
    }

    static void cast_env(lua_State* L, base::subprocess::spawn& self) {
        if (LUA_TTABLE == lua_getfield(L, 1, "env")) {
            lua_next(L, 1);
            while (lua_next(L, -2)) {
                if (LUA_TSTRING == lua_type(L, -1)) {
                    self.env_set(luaL_checknativestring(L, -2), luaL_checknativestring(L, -1));
                }
                else {
                    self.env_del(luaL_checknativestring(L, -2));
                }
                lua_pop(L, 1);
            }
        }
        lua_pop(L, 1);
    }

#if defined(_WIN32)
    static void cast_option(lua_State* L, base::subprocess::spawn& self)
    {
        if (LUA_TSTRING == lua_getfield(L, 1, "console")) {
            std::string console = luaL_checkstring(L, -1);
            if (console == "new") {
                self.set_console(base::subprocess::console::eNew);
            }
            else if (console == "disable") {
                self.set_console(base::subprocess::console::eDisable);
            }
            else if (console == "inherit") {
                self.set_console(base::subprocess::console::eInherit);
            }
        }
        lua_pop(L, 1);

        if (LUA_TBOOLEAN == lua_getfield(L, 1, "windowHide")) {
            if (lua_toboolean(L, -1)) {
                self.hide_window();
            }
        }
        lua_pop(L, 1);
    }
#else
    static void cast_option(lua_State* , base::subprocess::spawn&)
    { }
#endif

    static int spawn(lua_State* L) {
        luaL_checktype(L, 1, LUA_TTABLE);
        int retn = 0;
        base::subprocess::spawn spawn;
        native_args args = cast_args(L);
        if (args.size() <= 1) {
            return 0;
        }

        std::optional<nativestring> cwd = cast_cwd(L);
        cast_env(L, spawn);
        cast_option(L, spawn);

        FILE* f_stdin = cast_stdio(L, "stdin");
        if (f_stdin) {
            spawn.redirect(base::subprocess::stdio::eInput, f_stdin);
            retn++;
        }
        FILE* f_stdout = cast_stdio(L, "stdout");
        if (f_stdout) {
            spawn.redirect(base::subprocess::stdio::eOutput, f_stdout);
            retn++;
        }
        FILE* f_stderr = cast_stdio(L, "stderr");
        if (f_stderr) {
            spawn.redirect(base::subprocess::stdio::eError, f_stderr);
            retn++;
        }
        if (!spawn.exec(args, cwd? cwd->c_str(): 0)) {
            return 0;
        }
        process::constructor(L, spawn);
        retn += 1;
        lua_insert(L, -retn);
        return retn;
    }
}

static int peek(lua_State* L) {
    luaL_Stream* p = (luaL_Stream*)luaL_checkudata(L, 2, LUA_FILEHANDLE);
    lua_pushinteger(L, base::subprocess::pipe::peek(p->f));
    return 1;
}

extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int luaopen_subprocess(lua_State* L)
{
    static luaL_Reg mt[] = {
        { "wait", process::wait },
        { "kill", process::kill },
        { "get_id", process::get_id },
        { "is_running", process::is_running },
        { "__gc", process::destructor },
        { NULL, NULL }
    };
    luaL_newmetatable(L, "subprocess");
    luaL_setfuncs(L, mt, 0);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");

    static luaL_Reg lib[] = {
        { "spawn", spawn::spawn },
        { "peek", peek },
        { NULL, NULL }
    };
    luaL_newlib(L, lib);
    return 1;
}
