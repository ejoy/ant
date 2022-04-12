#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <stdio.h>
#include <stdint.h>
#include "fileinterface.h"

struct file_factory {
    lua_State *L;
};

static file_handle
fopen_(struct file_factory *ff, const char *filename, const char *mode) {
    lua_State *L = ff->L;
    lua_pushvalue(L, 1);
    lua_pushstring(L, filename);
    if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
        lua_pop(L, 1);  // pop error object
        return NULL;
    }
    const char *realname = lua_tostring(L, -1);
    FILE *f;
    fopen_s(&f, realname, mode);
    lua_pop(L, 1);  // pop realname
    return (file_handle)f;
}

static void
fclose_(struct file_factory *f, file_handle handle) {
    fclose((FILE *)handle);
}

static size_t
fread_(struct file_factory *f, file_handle handle, void *buffer, size_t sz) {
    return fread(buffer, 1, sz, (FILE *)handle);
}

static size_t
fwrite_(struct file_factory *f, file_handle handle, const void *buffer, size_t sz) {
    return fwrite(buffer, 1, sz, (FILE *)handle);
}

static int
fseek_(struct file_factory *f, file_handle handle, size_t offset, int origin) {
    return fseek((FILE *)handle, (long int)offset, origin); 
}

static size_t
ftell_(struct file_factory *f, file_handle handle) {
    return ftell((FILE *)handle);
}

static int
lfactory(lua_State *L) {
    struct wrapper {
        struct file_interface i;
        struct file_factory f;
    };

    static struct file_api apis = {
        fopen_,
        fclose_,
        fread_,
        fwrite_,
        fseek_,
        ftell_,
    };

    struct wrapper *f = (struct wrapper *)lua_newuserdatauv(L, sizeof(*f), 1);
    f->f.L = lua_newthread(L);
    lua_setiuservalue(L, -2, 1);
    f->i.api = &apis;

    luaL_checktype(L, 1, LUA_TTABLE);
    if (lua_getfield(L, 1, "preopen") != LUA_TFUNCTION) {
        return luaL_error(L, "Need preopen function");
    }

    lua_xmove(L, f->f.L, 1);

    return 1;
}

LUAMOD_API int
luaopen_fileinterface(lua_State *L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        { "factory", lfactory },
        { NULL, NULL },
    };
    luaL_newlib(L, l);

    return 1;    
}

#ifdef FILE_INTERFACE_TEST

struct box_file {
    struct file_interface *f;
    file_handle handle;
};

static int
lclose(lua_State *L) {
    struct box_file *ud = (struct box_file *)luaL_checkudata(L, 1, "FILE");
    if (ud->handle) {
        file_close(ud->f, ud->handle);
        ud->handle = NULL;
    }
    return 0;
}

static int
lread(lua_State *L) {
    struct box_file *ud = (struct box_file *)luaL_checkudata(L, 1, "FILE");
    if (ud->handle == NULL)
        return luaL_error(L, "read closed file");
    size_t sz = luaL_checkinteger(L, 2);
    void *buffer = lua_newuserdatauv(L, sz, 0);
    sz = file_read(ud->f, ud->handle, buffer, sz);
    lua_pushlstring(L, buffer, sz);
    return 1;
}

static int
lopen(lua_State *L) {
    struct file_interface *f = (struct file_interface *)lua_touserdata(L, 1);
    const char * filename = luaL_checkstring(L, 2);
    const char * mode = luaL_checkstring(L, 3);
    file_handle handle = file_open(f, filename, mode);
    if (handle == NULL)
        return luaL_error(L, "Can't open %s", filename);
    struct box_file *ud = (struct box_file *)lua_newuserdatauv(L, sizeof(*f), 1);
    lua_pushvalue(L, 1);
    lua_setiuservalue(L, -2, 1);
    ud->f = f;
    ud->handle = handle;
    if (luaL_newmetatable(L, "FILE")) {
        luaL_Reg l[] = {
            { "read", lread },
            { "close", lclose },
            { "__gc", lclose },
            { "__index", NULL },
            { NULL, NULL },
        };
        luaL_setfuncs(L, l, 0);
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
    }
    lua_setmetatable(L, -2);
    return 1;     
}

LUAMOD_API int
luaopen_fileinterface_test(lua_State *L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        { "open", lopen },
        { NULL, NULL },
    };
    luaL_newlib(L, l);
    return 1;
}

#endif
