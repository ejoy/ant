#include "imgui_lua_util.h"
#include "backend/imgui_impl_bgfx.h"
#include <bee/nonstd/unreachable.h>

namespace imgui_lua::util {

static lua_CFunction str_format = NULL;

lua_Integer field_tointeger(lua_State* L, int idx, lua_Integer i) {
    lua_geti(L, idx, i);
    auto v = luaL_checkinteger(L, -1);
    lua_pop(L, 1);
    return v;
}

lua_Number field_tonumber(lua_State* L, int idx, lua_Integer i) {
    lua_geti(L, idx, i);
    auto v = luaL_checknumber(L, -1);
    lua_pop(L, 1);
    return v;
}

bool field_toboolean(lua_State* L, int idx, lua_Integer i) {
    lua_geti(L, idx, i);
    bool v = !!lua_toboolean(L, -1);
    lua_pop(L, 1);
    return v;
}

ImTextureID get_texture_id(lua_State* L, int idx) {
    int lua_handle = (int)luaL_checkinteger(L, idx);
    if (auto id = ImGui_ImplBgfx_GetTextureID(lua_handle)) {
    	return *id;
    }
    luaL_error(L, "Invalid handle type TEXTURE");
    std::unreachable();
}

const char* format(lua_State* L, int idx) {
    lua_pushcfunction(L, str_format);
    lua_insert(L, idx);
    lua_call(L, lua_gettop(L) - idx, 1);
    return lua_tostring(L, -1);
}

void create_table(lua_State* L, std::span<TableInteger> l) {
    lua_createtable(L, 0, (int)l.size());
    for (auto const& e : l) {
        lua_pushinteger(L, e.value);
        lua_setfield(L, -2, e.name);
    }
}

void set_table(lua_State* L, std::span<TableAny> l) {
    for (auto const& e : l) {
        e.value(L);
        lua_setfield(L, -2, e.name);
    }
}

static int make_flags(lua_State* L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	int i, t;
	lua_Integer r = 0;
	for (i = 1; (t = lua_geti(L, 1, i)) != LUA_TNIL; i++) {
		if (t != LUA_TSTRING)
			luaL_error(L, "Flag name should be string, it's %s", lua_typename(L, t));
		if (lua_gettable(L, lua_upvalueindex(1)) != LUA_TNUMBER) {
			lua_geti(L, 1, i);
			luaL_error(L, "Invalid flag %s.%s", lua_tostring(L, lua_upvalueindex(2)), lua_tostring(L, -1));
		}
		lua_Integer v = lua_tointeger(L, -1);
		lua_pop(L, 1);
		r |= v;
	}
	lua_pushinteger(L, r);
	return 1;
}

void flags_gen(lua_State* L, const char* name) {
	lua_pushstring(L, name);
	lua_pushcclosure(L, make_flags, 2);
}

void init(lua_State* L) {
    luaopen_string(L);
    lua_getfield(L, -1, "format");
    str_format = lua_tocfunction(L, -1);
    lua_pop(L, 2);
}

}
