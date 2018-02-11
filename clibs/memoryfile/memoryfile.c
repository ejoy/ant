// Modify from https://github.com/LuaDist/lua-memoryfile
// Support lua 5.3 by Cloud Wu
// Change open api, use virtual filename instead string

#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include <inttypes.h>
#include <string.h>
#include <stdio.h>
#include <assert.h>

#define MEMORYFILE_MT_NAME ("3a4d95f2-66e7-11dc-ad52-00e081225ce5")
#define MEMORTFILE_SYSTEM "MEMORYFILESYSTEM"

#define MEMORYFILE_MIN_BUF_SIZE 1024

#define VERSION "1.2"

typedef struct MemoryFile_ {
    char *buf;
    size_t buf_size, buf_max_size, buf_pos;
    int append;     /* if true, all output goes at end of file */
    int modify;
} MemoryFile;

static void
ensure_buf_size (MemoryFile *f, lua_State *L, size_t min_size) {
    size_t new_size;
    lua_Alloc alloc;
    void *alloc_ud;

    /* Leave space for putting a NUL byte at the end for read_number() */
    assert(min_size > 0);
    ++min_size;

    if (f->buf_max_size >= min_size)
        return;

    new_size = f->buf_max_size * 2;
    if (new_size < min_size)
        new_size = min_size;
    if (new_size < MEMORYFILE_MIN_BUF_SIZE)
        new_size = MEMORYFILE_MIN_BUF_SIZE;

    alloc = lua_getallocf(L, &alloc_ud);
    f->buf = alloc(alloc_ud, f->buf, f->buf_max_size, new_size);
    assert(f->buf);
}

static void
delete_memoryfile_buffer (MemoryFile *f, lua_State *L) {
    lua_Alloc alloc;
    void *alloc_ud;

    if (f->buf) {
        alloc = lua_getallocf(L, &alloc_ud);
        f->buf = alloc(alloc_ud, f->buf, f->buf_max_size, 0);
    }

    f->buf_size = f->buf_max_size = f->buf_pos = 0;
}

static int
nil_and_error_message (lua_State *L, const char *msg) {
    lua_pushnil(L);
    lua_pushstring(L, msg);
    return 2;
}

// use lua 5.3 api to read number.
static int
read_number (MemoryFile *f, lua_State *L) {
    if (!f->buf)
        return 0;       /* empty file */
    ensure_buf_size(f, L, f->buf_size + 1);
    f->buf[f->buf_size] = '\0';
	size_t bytes = lua_stringtonumber(L, f->buf + f->buf_pos);
	if (bytes == 0) {
		return 0;
	}
	f->buf_pos += bytes;
	return 1;
}

static int
read_line (MemoryFile *f, lua_State *L) {
    const char *e = memchr(f->buf + f->buf_pos, '\n', f->buf_size - f->buf_pos);
    size_t len = e ? (size_t) (e - (f->buf + f->buf_pos))
                   : f->buf_size - f->buf_pos;
    size_t new_pos = f->buf_pos + len;
    int success;
    if (e)
        ++new_pos;      /* skip newline */
    success = f->buf_pos != f->buf_size;
    lua_pushlstring(L, f->buf + f->buf_pos, len);
    f->buf_pos = new_pos;
    return success;
}

static int
test_eof (MemoryFile *f, lua_State *L) {
    lua_pushlstring(L, 0, 0);
    return f->buf_pos != f->buf_size;
}

static int
read_chars (MemoryFile *f, lua_State *L, size_t n) {
    size_t rlen = f->buf_size - f->buf_pos;
    if (rlen > n)
        rlen = n;
    lua_pushlstring(L, f->buf + f->buf_pos, rlen);
    f->buf_pos += rlen;
    return 1;
}

static int
lines_iter (lua_State *L) {
    MemoryFile *f = lua_touserdata(L, lua_upvalueindex(1));
    return read_line(f, L) ? 1 : 0;
}

static int
memfile_open (lua_State *L) {
    size_t data_len;
    const char *data, *mode;
    char modechar;
    MemoryFile *f;
    int memfilet;

    if (lua_gettop(L) > 2)
        return luaL_error(L, "too many arguments to memoryfile.open()");

    mode = luaL_optstring(L, 2, "r");
    modechar = mode ? mode[0] : 'r';
    if (modechar != 'r' && modechar != 'w' && modechar != 'a')
        luaL_argerror(L, 2, "mode must start with 'r', 'w', or 'a'");

    luaL_checktype(L, 1, LUA_TSTRING);	// memfile name
    lua_getfield(L, LUA_REGISTRYINDEX, MEMORTFILE_SYSTEM);
    lua_pushvalue(L, 1);
    memfilet = lua_gettable(L, -2);
    if (memfilet == LUA_TNIL) {
        if (modechar == 'r') {
            lua_pushnil(L);
            lua_pushfstring(L, "Memfile %s not found", lua_tostring(L, 1));
            return 2;
        }
        data = NULL;
        data_len = 0;
    } else {
        if (memfilet == LUA_TBOOLEAN ||
            (memfilet == LUA_TSTRING && modechar != 'r')) {
            lua_pushnil(L);
            lua_pushfstring(L, "Memfile %s locked", lua_tostring(L, 1));
            return 2;
        }
        data = lua_tolstring(L, -1, &data_len);
    }
    if (modechar == 'w' || modechar == 'a') {
        lua_pushvalue(L, 1);
        lua_pushboolean(L, 1);
        lua_settable(L, -4);
        if (modechar == 'w') {
            data = NULL;
            data_len = 0;
        }
    }
    lua_pop(L, 2);

    f = lua_newuserdata(L, sizeof(MemoryFile));
    lua_pushvalue(L, 1);
    lua_setuservalue(L, -2);  /* save file name */
    f->buf = 0;
    f->buf_size = f->buf_max_size = f->buf_pos = 0;
    f->append = modechar == 'a';
    f->modify = modechar != 'r';

    luaL_getmetatable(L, MEMORYFILE_MT_NAME);
    lua_setmetatable(L, -2);

    if (modechar != 'w' && data_len > 0) {
        ensure_buf_size(f, L, data_len);
        memcpy(f->buf, data, data_len);
        f->buf_size = data_len;
    }

    return 1;
}

static int
memfile_noop (lua_State *L) {
    lua_pushboolean(L, 1);
    return 1;
}

static int
memfile_close (lua_State *L) {
    MemoryFile *f = luaL_checkudata(L, 1, MEMORYFILE_MT_NAME);

    if (f->modify) {
        /* save content */
        lua_getfield(L, LUA_REGISTRYINDEX, MEMORTFILE_SYSTEM);
        lua_getuservalue(L, 1);
        lua_pushlstring(L, f->buf, f->buf_size);
        lua_settable(L, -3);
        lua_pop(L, 1);
        f->modify = 0;
    }
    
    delete_memoryfile_buffer(f, L);

    lua_pushboolean(L, 1);      /* always successful */
    return 1;
}

static int
memfile_lines (lua_State *L) {
    lua_pushcclosure(L, lines_iter, 1);
    return 1;
}

static int
memfile_read (lua_State *L) {
    MemoryFile *f = luaL_checkudata(L, 1, MEMORYFILE_MT_NAME);
    int nargs = lua_gettop(L) - 1;
    int success;
    int n;

    if (nargs == 0) {   /* no arguments? */
        success = read_line(f, L);
        n = 3;          /* to return 1 result */
    }
    else {  /* ensure stack space for all results and for auxlib's buffer */
        luaL_checkstack(L, nargs + LUA_MINSTACK, "too many arguments");
        success = 1;
        for (n = 2; nargs-- && success; n++) {
            if (lua_type(L, n) == LUA_TNUMBER) {
                size_t l = (size_t) lua_tointeger(L, n);
                success = (l == 0) ? test_eof(f, L) : read_chars(f, L, l);
            }
            else {
                const char *p = lua_tostring(L, n);
				char c = p[0];
                luaL_argcheck(L, p, n, "invalid option");
				if (c == '*')
					c = p[1];
                switch (c) {
                    case 'n':  /* number */
                        success = read_number(f, L);
                        break;
                    case 'l':  /* line */
                        success = read_line(f, L);
                        break;
                    case 'a':  /* all the rest of the file */
                        read_chars(f, L, ~((size_t)0)); /* MAX_SIZE_T bytes */
                        success = 1; /* always success */
                        break;
                    default:
                        return luaL_argerror(L, n, "invalid format");
                }
            }
        }
    }

    if (!success) {
        lua_pop(L, 1);      /* remove last result */
        lua_pushnil(L);     /* push nil instead */
    }

    return n - 2;
}

static int
memfile_seek (lua_State *L) {
    static const char *const modenames[] = { "set", "cur", "end", 0 };
    MemoryFile *f = luaL_checkudata(L, 1, MEMORYFILE_MT_NAME);
    int op = luaL_checkoption(L, 2, "cur", modenames);
    lua_Integer new_pos = luaL_optinteger(L, 3, 0);

    if (op == 1)            /* SEEK_CUR */
        new_pos = f->buf_pos + new_pos;
    else if (op == 2)       /* SEEK_END */
        new_pos = f->buf_size + new_pos;

    if (new_pos < 0)
        return nil_and_error_message(L, "seek to before start of memory file");
    else if ((size_t) new_pos > f->buf_size)
        return nil_and_error_message(L, "seek to after end of memory file");

    f->buf_pos = (size_t) new_pos;
    lua_pushinteger(L, f->buf_pos);
    return 1;
}

static int
memfile_write (lua_State *L) {
    size_t new_bytes, tmpsize, end_pos;
    int i, num_args = lua_gettop(L);
    const char *data;
    MemoryFile *f = luaL_checkudata(L, 1, MEMORYFILE_MT_NAME);
    f->modify = 1;

    new_bytes = 0;
    for (i = 2; i <= num_args; ++i) {
        if (!lua_tolstring(L, i, &tmpsize))
            return luaL_argerror(L, i, "must be string or number");
        new_bytes += tmpsize;
    }

    if (new_bytes == 0)
        ;   /* nothing to write */
    else if (f->append || f->buf_pos == f->buf_size) {
        /* Append data to end of buffer */
        ensure_buf_size(f, L, f->buf_size + new_bytes);
        for (i = 2; i <= num_args; ++i) {
            data = lua_tolstring(L, i, &tmpsize);
            memcpy(f->buf + f->buf_size, data, tmpsize);
            f->buf_size += tmpsize;
        }
        if (!f->append)
            f->buf_pos = f->buf_size;
    }
    else {
        /* Write over the top of some existing data */
        end_pos = f->buf_pos + new_bytes;
        if (end_pos > f->buf_size) {
            ensure_buf_size(f, L, end_pos);
            f->buf_size = end_pos;
        }
        for (i = 2; i <= num_args; ++i) {
            data = lua_tolstring(L, i, &tmpsize);
            memcpy(f->buf + f->buf_pos, data, tmpsize);
            f->buf_pos += tmpsize;
        }
    }

    lua_pushboolean(L, 1);
    return 1;
}

static int
memfile_gc (lua_State *L) {
    MemoryFile *f = luaL_checkudata(L, 1, MEMORYFILE_MT_NAME);
    delete_memoryfile_buffer(f, L);
    return 0;
}

static int
memfile_tostring (lua_State *L) {
    MemoryFile *f = luaL_checkudata(L, 1, MEMORYFILE_MT_NAME);
    lua_pushlstring(L, f->buf, f->buf_size);
    return 1;
}

static int
memfile_size (lua_State *L) {
    lua_Integer new_size;
    MemoryFile *f = luaL_checkudata(L, 1, MEMORYFILE_MT_NAME);
    size_t old_size = f->buf_size;

    if (!lua_isnoneornil(L, 2)) {
        new_size = lua_tointeger(L, 2);
        if (new_size == 0) {
            luaL_argcheck(L, lua_isnumber(L, 2), 2, "new size must be integer");
            delete_memoryfile_buffer(f, L);
        }
        else if (new_size < 0)
            luaL_argerror(L, 2, "new size must be >= zero");
        else {
            if ((size_t) new_size > f->buf_size) {
                ensure_buf_size(f, L, new_size);
                memset(f->buf + f->buf_size, 0, new_size - f->buf_size);
            }
            f->buf_size = (size_t) new_size;
            if (f->buf_pos > f->buf_size)
                f->buf_pos = f->buf_size;
        }
    }

    lua_pushinteger(L, old_size);
    return 1;
}

static const luaL_Reg
memfile_lib[] = {
    /* Emulations of the methods on standard Lua file handle objects: */
    { "close", memfile_close },
    { "flush", memfile_noop },
    { "lines", memfile_lines },
    { "read", memfile_read },
    { "seek", memfile_seek },
    { "setvbuf", memfile_noop },
    { "write", memfile_write },
    { "__gc", memfile_gc },
    { "__tostring", memfile_tostring },
    /* Methods not provided by the standard Lua file handle objects: */
    { "size", memfile_size },
    { 0, 0 }
};


LUAMOD_API int
luaopen_memoryfile (lua_State *L) {
    const luaL_Reg *l;

#ifdef VALGRIND_LUA_MODULE_HACK
    /* Hack to allow Valgrind to access debugging info for the module. */
    luaL_getmetatable(L, "_LOADLIB");
    lua_pushnil(L);
    lua_setfield(L, -2, "__gc");
    lua_pop(L, 1);
#endif

    /* Create the table to return from 'require' */
    lua_createtable(L, 0, 3);
    lua_pushliteral(L, "_NAME");
    lua_pushliteral(L, "memoryfile");
    lua_rawset(L, -3);
    lua_pushliteral(L, "_VERSION");
    lua_pushliteral(L, VERSION);
    lua_rawset(L, -3);
    lua_pushliteral(L, "open");
    lua_pushcfunction(L, memfile_open);
    lua_rawset(L, -3);

    lua_newtable(L);
    lua_setfield(L, LUA_REGISTRYINDEX, MEMORTFILE_SYSTEM);	/* for all the memfile */

    /* Create the metatable for file handle objects returned from .open() */
    luaL_newmetatable(L, MEMORYFILE_MT_NAME);
    lua_pushliteral(L, "_NAME");
    lua_pushliteral(L, "memoryfile-object");
    lua_rawset(L, -3);

    for (l = memfile_lib; l->name; ++l) {
        lua_pushstring(L, l->name);
        lua_pushcfunction(L, l->func);
        lua_rawset(L, -3);
    }

    lua_pushliteral(L, "__index");
    lua_pushvalue(L, -2);
    lua_rawset(L, -3);
    lua_pop(L, 1);

    return 1;
}

/* vi:set ts=4 sw=4 expandtab: */
