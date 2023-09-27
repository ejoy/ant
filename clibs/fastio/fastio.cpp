#include <lua.hpp>
#include <errno.h>
#include <string.h>
#include <assert.h>

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

static int push_error(lua_State *L, const char* what, const char *filename) {
    int en = errno;
    luaL_pushfail(L);
    lua_pushfstring(L, "cannot %s %s: %s", what, filename, strerror(en));
    lua_pushinteger(L, en);
    return 3;
}

static int raise_error(lua_State *L, const char* what, const char *filename) {
    return luaL_error(L, "cannot %s %s: %s", what, filename, strerror(errno));
}

static int readall(lua_State *L) {
    const char* filename = luaL_checkstring(L, 1);
    file_t f = file_t::open(L, filename);
    if (!f.suc()) {
#if defined(__ANT_RUNTIME__)
        return raise_error(L, "open", luaL_optstring(L, 2, filename));
#else
        return raise_error(L, "open", filename);
#endif
    }
    size_t size = f.size();
    void* data = create_memory(L, size);
    size_t nr = f.read(data, size);
    assert(nr == size);
    if (nr != size) {
        lua_pushlightuserdata(L, data);
        lua_pushinteger(L, nr);
        lua_rotate(L, -3, 2);
        return 3;
    }
    return 1;
}

static int readall_s(lua_State *L) {
    const char* filename = luaL_checkstring(L, 1);
    file_t f = file_t::open(L, filename);
    if (!f.suc()) {
#if defined(__ANT_RUNTIME__)
        return raise_error(L, "open", luaL_optstring(L, 2, filename));
#else
        return raise_error(L, "open", filename);
#endif
    }
    size_t size = f.size();
    void* data = create_memory(L, size);
    size_t nr = f.read(data, size);
    lua_pushlstring(L, (const char*)data, nr);
    return 1;
}

struct LoadF {
    int n;
    FILE *f;
    char buff[1024];
};

static const char* getF(lua_State *L, void *ud, size_t *size) {
    LoadF* lf = (LoadF*)ud;
    (void)L;
    if (lf->n > 0) {
        *size = lf->n;
        lf->n = 0;
    }
    else { 
        if (feof(lf->f)) return NULL;
        *size = fread(lf->buff, 1, sizeof(lf->buff), lf->f);
    }
    return lf->buff;
}

static int loadfile(lua_State *L) {
    const char* filename = luaL_checkstring(L, 1);
#if defined(__ANT_RUNTIME__)
    const char* symbol = luaL_optstring(L, 2, filename);
#else
    const char* symbol = filename;
#endif
    lua_settop(L, 3);
    file_t f = file_t::open(L, filename);
    if (!f.suc()) {
        return push_error(L, "open", symbol);
    }
    LoadF lf;
    lf.f = f.f;
    lf.n = 0;
    lua_pushfstring(L, "@%s", symbol);
    int status = lua_load(L, getF, &lf, lua_tostring(L, -1), "t");
    if (ferror(lf.f)) {
        return push_error(L, "read", symbol);
    }
    if (status != LUA_OK) {
        luaL_pushfail(L);
        lua_insert(L, -2);
        return 2;
    }
    if (!lua_isnoneornil(L, 3)) {
        lua_pushvalue(L, 3);
        if (!lua_setupvalue(L, -2, 1)) {
            lua_pop(L, 1);
        }
    }
    return 1;
}

static int
tostring(lua_State *L){
    luaL_checktype(L, 1, LUA_TUSERDATA);
    const void * b = lua_touserdata(L, 1);
    const size_t s = (size_t)luaL_checkinteger(L, 2);
    const size_t offset = (size_t)luaL_optinteger(L, 3, 1) - 1;
    lua_pushlstring(L, (const char*)b+offset, s);
    return 1;
}

extern "C" int
luaopen_fastio(lua_State* L) {
    luaL_Reg l[] = {
        {"readall", readall},
        {"readall_s", readall_s},
        {"loadfile", loadfile},
        {"mem2str", tostring},
        {NULL, NULL},
    };
    luaL_newlib(L, l);
    return 1;
}
