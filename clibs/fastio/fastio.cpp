#include <lua.hpp>
#include <errno.h>
#include <string.h>
#include <assert.h>
#include <array>
#include <optional>
#include "memfile.h"

#include <bee/nonstd/unreachable.h>
#include <bee/utility/zstring_view.h>
#include <bee/win/cwtf8.h>

extern "C" {
#include "sha1.h"
}

namespace fileutil {
    static FILE* open(lua_State* L, bee::zstring_view filename) noexcept {
#if defined(_WIN32)
        size_t wlen = wtf8_to_utf16_length(filename.data(), filename.size());
        if (wlen == (size_t)-1) {
            errno = EILSEQ;
            return NULL;
        }
        wchar_t* wfilename = (wchar_t*)lua_newuserdatauv(L, (wlen + 1) * sizeof(wchar_t), 0);
        if (!wfilename) {
            errno = ENOMEM;
            return NULL;
        }
        wtf8_to_utf16(filename.data(), filename.size(), wfilename, wlen);
        wfilename[wlen] = L'\0';
        return _wfopen(wfilename, L"rb");
#else
        return fopen(filename.data(), "r");
#endif
    }
    static size_t size(FILE* f) noexcept {
#if defined(_WIN32)
        _fseeki64(f, 0, SEEK_END);
        long long size = _ftelli64(f);
        _fseeki64(f, 0, SEEK_SET);
#else
        fseeko(f, 0, SEEK_END);
        off_t size = ftello(f);
        fseeko(f, 0, SEEK_SET);
#endif
        return (size_t)size;
    }
    static size_t read(FILE* f, void* buf, size_t sz) noexcept {
        return fread(buf, sizeof(char), sz, f);
    }
    static void close(FILE* f) noexcept {
        int rc = fclose(f);
        (void)rc;
        assert(rc == 0);
    }
    static memory_file* readall_v(lua_State* L, bee::zstring_view filename) noexcept {
        FILE* f = fileutil::open(L, filename);
        if (!f) {
            return nullptr;
        }
        size_t size = fileutil::size(f);
        auto file = memory_file_alloc(size);
        if (!file) {
            fileutil::close(f);
            luaL_error(L, "not enough memory");
            std::unreachable();
        }
        size_t nr = fileutil::read(f, (void*)file->data, file->sz);
        if (nr != size) {
            memory_file_close(file);
            fileutil::close(f);
            luaL_error(L, "unknown read error");
            std::unreachable();
        }
        fileutil::close(f);
        lua_pushlightuserdata(L, file);
        return file;
    }
    static std::optional<std::string_view> readall_s(lua_State* L, bee::zstring_view filename) noexcept {
        FILE* f = fileutil::open(L, filename);
        if (!f) {
            return std::nullopt;
        }
        size_t size = fileutil::size(f);
        void* data = lua_newuserdatauv(L, size, 0);
        if (!data) {
            fileutil::close(f);
            luaL_error(L, "not enough memory");
            std::unreachable();
        }
        size_t nr = fileutil::read(f, data, size);
        fileutil::close(f);
        return std::string_view { (const char*)data, nr };
    }
}

template <bool RAISE>
static int raise_error(lua_State *L, const char* what, const char *filename) {
    int en = errno;
    if constexpr (RAISE) {
        return luaL_error(L, "cannot %s %s: %s", what, filename, strerror(en));
    }
    else {
        luaL_pushfail(L);
        lua_pushfstring(L, "cannot %s %s: %s", what, filename, strerror(en));
        lua_pushinteger(L, en);
        return 3;
    }
}

static bee::zstring_view getfile(lua_State *L) {
    if (lua_type(L, 1) != LUA_TSTRING) {
        if (lua_type(L, 2) == LUA_TSTRING) {
            luaL_error(L, "unable to decode filename: %s", lua_tostring(L, 2));
        }
        else {
            luaL_error(L, "unable to decode filename: type(%s)", luaL_typename(L, 1));
        }
        return { nullptr, 0 };
    }
    size_t len      = 0;
    const char* buf = lua_tolstring(L, 1, &len);
    return { buf, len };
}

// Although it will be accessed by multiple threads,
// we only modify it once during initialization, so it is thread-safe.
static bool readability = true;

static int set_readability(lua_State *L) {
    readability = !!lua_toboolean(L, 1);
    return 0;
}

static const char* getsymbol(lua_State *L, bee::zstring_view filename) {
    if (!readability) {
        return luaL_optstring(L, 2, filename.data());
    }
    else {
        return filename.data();
    }
}

struct wrap {
    memory_file* file;
};

static int wrap_close(lua_State* L) {
    struct wrap& wrap = *(struct wrap*)lua_touserdata(L, 1);
    if (wrap.file) {
        memory_file_close(wrap.file);
        wrap.file = nullptr;
    }
    return 0;
}

static int wrap_closure(lua_State* L) {
    memory_file* file = (memory_file*)lua_touserdata(L, lua_upvalueindex(1));
    lua_pushlightuserdata(L, (void*)file->data);
    lua_pushinteger(L, file->sz);
    struct wrap& wrap = *(struct wrap*)lua_newuserdatauv(L, sizeof(struct wrap), 0);
    wrap.file = file;
    if (luaL_newmetatable(L, "fastio::wrap")) {
        luaL_Reg lib[] = {
            { "__close", wrap_close },
            { NULL, NULL },
        };
        luaL_setfuncs(L, lib, 0);
    }
    lua_setmetatable(L, -2);
    return 3;
}

template <bool RAISE>
static int readall_v(lua_State *L) {
    auto filename = getfile(L);
    lua_settop(L, 2);
    auto file = fileutil::readall_v(L, filename);
    if (!file) {
        return raise_error<RAISE>(L, "open", getsymbol(L, filename));
    }
    lua_pushlightuserdata(L, file);
    return 1;
}

template <bool RAISE>
static int readall_f(lua_State *L) {
    auto filename = getfile(L);
    lua_settop(L, 2);
    auto file = fileutil::readall_v(L, filename);
    if (!file) {
        return raise_error<RAISE>(L, "open", getsymbol(L, filename));
    }
    lua_pushlightuserdata(L, file);
    lua_pushcclosure(L, wrap_closure, 1);
    return 1;
}

template <bool RAISE>
static int readall_s(lua_State *L) {
    auto filename = getfile(L);
    lua_settop(L, 2);
    auto str = fileutil::readall_s(L, filename);
    if (!str) {
        return raise_error<RAISE>(L, "open", getsymbol(L, filename));
    }
    lua_pushlstring(L, str->data(), str->size());
    return 1;
}

static char hex[] = {
    '0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
};

template <bool RAISE>
static int sha1(lua_State *L) {
    auto filename = getfile(L);
    lua_settop(L, 2);
    FILE* f = fileutil::open(L, filename);
    if (!f) {
        return raise_error<RAISE>(L, "open", getsymbol(L, filename));
    }
    std::array<uint8_t, 1024> buffer;
    SHA1_CTX ctx;
    sat_SHA1_Init(&ctx);
    for (;;) {
        size_t n = fileutil::read(f, buffer.data(), buffer.size());
        if (n != buffer.size()) {
            sat_SHA1_Update(&ctx, buffer.data(), n);
            break;
        }
        sat_SHA1_Update(&ctx, buffer.data(), buffer.size());
    }
    fileutil::close(f);
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

static int wrap(lua_State* L) {
    luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    lua_settop(L, 1);
    lua_pushcclosure(L, wrap_closure, 1);
    return 1;
}

static int tostring(lua_State *L) {
    luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    memory_file* file = (memory_file*)lua_touserdata(L, 1);
    if (lua_gettop(L) == 1) {
        lua_pushlstring(L, (const char*)file->data, file->sz);
        memory_file_close(file);
        return 1;
    }
    const size_t offset = (size_t)luaL_optinteger(L, 2, 1) - 1;
    const size_t size = (size_t)luaL_checkinteger(L, 3);
    lua_pushlstring(L, (const char*)file->data+offset, size);
    memory_file_close(file);
    return 1;
}

static int free(lua_State *L) {
    luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    memory_file* file = (memory_file*)lua_touserdata(L, 1);
    memory_file_close(file);
    return 0;
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

static int loadlua(lua_State* L) {
    luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    memory_file* file = (memory_file*)lua_touserdata(L, 1);
    const char* symbol = luaL_checkstring(L, 2);
    lua_settop(L, 3);
    LoadS ls;
    ls.s = (const char*)file->data;
    ls.size = file->sz;
    lua_pushfstring(L, "@%s", symbol);
    int status = lua_load(L, getS, &ls, lua_tostring(L, -1), "t");
    memory_file_close(file);
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

static int lmemfile(lua_State *L) {
	size_t sz;
	const char *content = luaL_checklstring(L, 1, &sz);
	struct memory_file *mf = memory_file_cstr(content, sz);
	lua_pushlightuserdata(L, mf);
	return 1;
}

extern "C" int
luaopen_fastio(lua_State* L) {
    luaL_Reg l[] = {
        {"set_readability", set_readability},
        {"readall_v", readall_v<true>},
        {"readall_v_noerr", readall_v<false>},
        {"readall_f", readall_f<true>},
        {"readall_s", readall_s<true>},
        {"readall_s_noerr", readall_s<false>},
        {"sha1", sha1<true>},
        {"str2sha1", str2sha1},
        {"wrap", wrap},
        {"tostring", tostring},
        {"free", free},
        {"loadlua", loadlua},
		{"memfile", lmemfile},
        {NULL, NULL},
    };
    luaL_newlib(L, l);
    return 1;
}
