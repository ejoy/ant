#pragma once

#include <lua.hpp>
#include <string_view>
#include <bee/nonstd/unreachable.h>

inline std::string_view getmemory(lua_State* L, int idx) {
	switch (lua_type(L, idx)) {
	case LUA_TSTRING: {
		size_t sz;
		const char* data = lua_tolstring(L, idx, &sz);
		return { data, sz };
	}
	case LUA_TUSERDATA: {
		const char* data = (const char*)lua_touserdata(L, idx);
		size_t sz = lua_rawlen(L, idx);
		return { data, sz };
	}
	case LUA_TFUNCTION: {
		lua_pushvalue(L, idx);
		lua_call(L, 0, 3);
		const char* data = (const char*)lua_touserdata(L, -3);
		size_t sz = (size_t)luaL_checkinteger(L, -2);
		lua_copy(L, -1, idx);
		lua_toclose(L, idx);
		lua_pop(L, 3);
		return { data, sz };
	}
	default:
		luaL_error(L, "unsupported type %s", luaL_typename(L, lua_type(L, idx)));
		std::unreachable();
	}
}
