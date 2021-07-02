#include <lua.hpp>
#include <errno.h>
#include <string.h>

#if defined(LUA_USE_POSIX)
#   include <sys/types.h>
#   define l_fseek(f,o,w)	fseeko(f,o,w)
#   define l_ftell(f)		ftello(f)
#   define l_seeknum		off_t
#elif defined(LUA_USE_WINDOWS) && !defined(_CRTIMP_TYPEINFO) && defined(_MSC_VER) && (_MSC_VER >= 1400)
#   define l_fseek(f,o,w)	_fseeki64(f,o,w)
#   define l_ftell(f)		_ftelli64(f)
#   define l_seeknum		__int64
#else
#   define l_fseek(f,o,w)	fseek(f,o,w)
#   define l_ftell(f)		ftell(f)
#   define l_seeknum		long
#endif

static void* create_memory(lua_State* L, size_t sz) {
    void* memory = lua_newuserdatauv(L, sz, 0);
    if (!memory) {
        luaL_error(L, "not enough memory");
        return NULL;
    }
    return memory;
}

#if defined(_WIN32)
#include <Windows.h>
static wchar_t* u2w(lua_State* L, const char *str) {
    int len = MultiByteToWideChar(CP_UTF8, 0, str, -1, NULL, 0);
    if (!len) {
        luaL_error(L, "MultiByteToWideChar Failed: %d", GetLastError());
        return NULL;
    }
    wchar_t* buf = (wchar_t*)create_memory(L, len * sizeof(wchar_t));
    int out_len = MultiByteToWideChar(CP_UTF8, 0, str, -1, buf, len);
    if (!out_len) {
        luaL_error(L, "MultiByteToWideChar Failed: %d", GetLastError());
        return NULL;
    }
    return buf;
}
#endif

struct file_t {
    static file_t open(lua_State* L, const char* filename) {
#if defined(_WIN32)
        return file_t { _wfopen(u2w(L, filename), L"rb") };
#else
        return file_t { fopen(filename, "r") };
#endif
    }
    ~file_t() {
        if (f) fclose(f);
    }
    bool suc() const {
        return !!f;
    }
    size_t size() {
        l_fseek(f, 0, SEEK_END);
        l_seeknum size = l_ftell(f);
        l_fseek(f, 0, SEEK_SET);
        return (size_t)size;
    }
    size_t read(void* buf, size_t sz) {
        return fread(buf, sizeof(char), sz, f);
    }
    FILE* f;
};

static int readall(lua_State *L) {
    const char *filename = luaL_checkstring(L, 1);
    file_t f = file_t::open(L, filename);
    if (!f.suc()) {
        int en = errno;
        luaL_pushfail(L);
        lua_pushfstring(L, "%s: %s", filename, strerror(en));
        lua_pushinteger(L, en);
        return 3;
    }
    size_t size = f.size();
    void* data = create_memory(L, size);
    size_t nr = f.read(data, size);
    lua_pushinteger(L, (lua_Integer)nr);
    return 2;
}

static int readall_s(lua_State *L) {
    const char *filename = luaL_checkstring(L, 1);
    file_t f = file_t::open(L, filename);
    if (!f.suc()) {
        int en = errno;
        luaL_pushfail(L);
        lua_pushfstring(L, "%s: %s", filename, strerror(en));
        lua_pushinteger(L, en);
        return 3;
    }
    size_t size = f.size();
    void* data = create_memory(L, size);
    size_t nr = f.read(data, size);
    lua_pushlstring(L, (const char*)data, size);
    return 1;
}

extern "C" int
luaopen_fastio(lua_State* L) {
    luaL_Reg l[] = {
        {"readall", readall},
        {"readall_s", readall_s},
        {NULL, NULL},
    };
    luaL_newlib(L, l);
    return 1;
}
