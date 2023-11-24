#include <lua.hpp>
#include <errno.h>
#include <string.h>
#include <assert.h>
#include <array>
extern "C" {
#include "../zip/luazip.h"
}

extern "C" {
#include "sha1.h"
}

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

#if defined(_WIN32)
#include <Windows.h>
static wchar_t* u2w(lua_State* L, const char *str) {
    int len = MultiByteToWideChar(CP_UTF8, 0, str, -1, NULL, 0);
    if (!len) {
        luaL_error(L, "MultiByteToWideChar Failed: %d", GetLastError());
        return NULL;
    }
    wchar_t* buf = (wchar_t*)lua_newuserdatauv(L, len * sizeof(wchar_t), 0);
    if (!buf) {
        luaL_error(L, "not enough memory");
        return NULL;
    }
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
    void close() {
        if (f) {
            fclose(f);
            f = NULL;
        }
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

static const char* getfile(lua_State *L) {
    if (lua_type(L, 1) != LUA_TSTRING) {
        if (lua_type(L, 2) == LUA_TSTRING) {
            luaL_error(L, "unable to decode filename: %s", lua_tostring(L, 2));
        }
        else {
            luaL_error(L, "unable to decode filename: type(%s)", luaL_typename(L, 1));
        }
        return nullptr;
    }
    return lua_tostring(L, 1);
}

static const char* getsymbol(lua_State *L, const char* filename) {
#if defined(__ANT_RUNTIME__)
    return luaL_optstring(L, 2, filename);
#else
    return filename;
#endif
}

static int readall(lua_State *L) {
    const char* filename = getfile(L);
    file_t f = file_t::open(L, filename);
    if (!f.suc()) {
        return raise_error(L, "open", getsymbol(L, filename));
    }
    size_t size = f.size();
    void* data = lua_newuserdatauv(L, size, 0);
    if (!data) {
        f.close();
        luaL_error(L, "not enough memory");
        return 0;
    }
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
    const char* filename = getfile(L);
    file_t f = file_t::open(L, filename);
    if (!f.suc()) {
        return raise_error(L, "open", getsymbol(L, filename));
    }
    size_t size = f.size();
    void* data = lua_newuserdatauv(L, size, 0);
    if (!data) {
        f.close();
        luaL_error(L, "not enough memory");
        return 0;
    }
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

struct LoadS {
    const char *s;
    size_t size;
};

static const char* getS(lua_State *L, void *ud, size_t *size) {
    LoadS *ls = (LoadS *)ud;
    (void)L;
    if (ls->size == 0) return NULL;
    *size = ls->size;
    ls->size = 0;
    return ls->s;
}

static int loadfile(lua_State *L) {
    const char* filename = getfile(L);
    const char* symbol = getsymbol(L, filename);
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

static char hex[] = {
    '0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
};

static int sha1(lua_State *L) {
    const char* filename = getfile(L);
    const char* symbol = getsymbol(L, filename);
    file_t f = file_t::open(L, filename);
    if (!f.suc()) {
        return raise_error(L, "open", symbol);
    }
    std::array<uint8_t, 1024> buffer;
    SHA1_CTX ctx;
    sat_SHA1_Init(&ctx);
    for (;;) {
        size_t n = f.read(buffer.data(), buffer.size());
        if (n != buffer.size()) {
            sat_SHA1_Update(&ctx, buffer.data(), n);
            break;
        }
        sat_SHA1_Update(&ctx, buffer.data(), buffer.size());
    }
    std::array<uint8_t, SHA1_DIGEST_SIZE> digest;
    std::array<char, SHA1_DIGEST_SIZE*2> hexdigest;
    sat_SHA1_Final(&ctx, digest.data());
    for (size_t i = 0; i < SHA1_DIGEST_SIZE; ++i) {
        auto u = digest[i];
        hexdigest[2*i+0] = hex[u / 16];
        hexdigest[2*i+1] = hex[u % 16];
    }
    lua_pushlstring(L, hexdigest.data(), hexdigest.size());
    return 1;
}

static int str2sha1(lua_State *L) {
	size_t sz = 0;
	const uint8_t * buffer = (const uint8_t *)luaL_checklstring(L, 1, &sz);
	SHA1_CTX ctx;
	sat_SHA1_Init(&ctx);
	sat_SHA1_Update(&ctx, buffer, sz);
    std::array<uint8_t, SHA1_DIGEST_SIZE> digest;
    std::array<char, SHA1_DIGEST_SIZE*2> hexdigest;
    sat_SHA1_Final(&ctx, digest.data());
    for (size_t i = 0; i < SHA1_DIGEST_SIZE; ++i) {
        auto u = digest[i];
        hexdigest[2*i+0] = hex[u / 16];
        hexdigest[2*i+1] = hex[u % 16];
    }
    lua_pushlstring(L, hexdigest.data(), hexdigest.size());
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

static int wrap_close(lua_State* L) {
    bool& alive = *(bool*)lua_touserdata(L, 1);
    if (alive) {
        alive = false;
        zip_reader_cache* cache = (zip_reader_cache*)lua_touserdata(L, lua_upvalueindex(1));
        luazip_close(cache);
    }
    return 0;
}

static int wrap_closure(lua_State* L) {
    zip_reader_cache* cache = (zip_reader_cache*)lua_touserdata(L, lua_upvalueindex(1));
    size_t len = 0;
    void* buf = luazip_data(cache, &len);
    lua_pushlightuserdata(L, buf);
    lua_pushinteger(L, len);
    bool& alive = *(bool*)lua_newuserdatauv(L, sizeof(bool), 0);
    alive = true;
    if (luaL_newmetatable(L, "fastio::wrap")) {
        luaL_Reg lib[] = {
            { "__gc", wrap_close },
            { "__close", wrap_close },
            { NULL, NULL },
        };
        lua_pushvalue(L, lua_upvalueindex(1));
        luaL_setfuncs(L, lib, 1);
    }
    lua_setmetatable(L, -2);
    return 3;
}

static int wrap(lua_State* L) {
    luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    lua_settop(L, 1);
    lua_pushcclosure(L, wrap_closure, 1);
    return 1;
}

static int readall_mem(lua_State *L) {
    const char* filename = getfile(L);
    file_t f = file_t::open(L, filename);
    if (!f.suc()) {
        return raise_error(L, "open", getsymbol(L, filename));
    }
    size_t size = f.size();
    auto cache = luazip_new(size, NULL);
    if (!cache) {
        f.close();
        luaL_error(L, "not enough memory");
        return 0;
    }
    auto buf = luazip_data(cache, nullptr);
    size_t nr = f.read(buf, size);
    if (nr != size) {
        luazip_close(cache);
        luaL_error(L, "unknown read error");
        return 0;
    }
    lua_pushlightuserdata(L, cache);
    return 1;
}

static int mem_loadlua(lua_State* L) {
    luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    zip_reader_cache* cache = (zip_reader_cache*)lua_touserdata(L, 1);
    const char* symbol = luaL_checkstring(L, 2);
    size_t len = 0;
    void* buf = luazip_data(cache, &len);
    LoadS ls;
    ls.s = (const char*)buf;
    ls.size = len;
    lua_pushfstring(L, "@%s", symbol);
    int status = lua_load(L, getS, &ls, lua_tostring(L, -1), "t");
    luazip_close(cache);
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

static int mem_tostring(lua_State *L) {
    luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    zip_reader_cache* cache = (zip_reader_cache*)lua_touserdata(L, 1);
    size_t len = 0;
    void* buf = luazip_data(cache, &len);
    lua_pushlstring(L, (const char*)buf, len);
    luazip_close(cache);
    return 1;
}

extern "C" int
luaopen_fastio(lua_State* L) {
    luaL_Reg l[] = {
        {"readall", readall},
        {"readall_s", readall_s},
        {"loadfile", loadfile},
        {"sha1", sha1},
        {"str2sha1", str2sha1},
        {"mem2str", tostring},

        {"wrap", wrap},
        {"readall_mem", readall_mem},
        {"mem_loadlua", mem_loadlua},
        {"mem_tostring", mem_tostring},
        {NULL, NULL},
    };
    luaL_newlib(L, l);
    return 1;
}
