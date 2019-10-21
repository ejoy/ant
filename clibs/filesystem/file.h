#pragma once

#include <lua.hpp>
#include <errno.h>
#include <string.h>

namespace ant::lua {
    inline int _fileclose(lua_State* L) {
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
    inline int newfile(lua_State* L, FILE* f) {
        luaL_Stream* pf = (luaL_Stream*)lua_newuserdatauv(L, sizeof(luaL_Stream), 0);
        luaL_setmetatable(L, LUA_FILEHANDLE);
        pf->closef = &_fileclose;
        pf->f = f;
        return 1;
    }
}
