#pragma once

#include <lua.hpp>
#include <functional>

namespace luabind {
	typedef std::function<void(lua_State*)> call_t;
	inline int errhandler(lua_State* L) {
		const char* msg = lua_tostring(L, 1);
		if (msg == NULL) {
			if (luaL_callmeta(L, 1, "__tostring") && lua_type(L, -1) == LUA_TSTRING)
				return 1;
			else
				msg = lua_pushfstring(L, "(error object is a %s value)", luaL_typename(L, 1));
		}
		luaL_traceback(L, L, msg, 1);
		return 1;
	}
	inline int function_call(lua_State* L) {
		call_t& f = *(call_t*)lua_touserdata(L, 1);
		f(L);
		return 0;
	}
	inline bool invoke(lua_State* L, call_t f) {
		lua_pushcfunction(L, errhandler);
		lua_pushcfunction(L, function_call);
		lua_pushlightuserdata(L, &f);
		if (lua_pcall(L, 1, 0, lua_gettop(L) - 2) != LUA_OK) {
			// todo: use Rml log
			lua_writestringerror("%s\n", lua_tostring(L, -1));
			lua_pop(L, 2);
			return false;
		}
		lua_pop(L, 1);
		return true;
	}
}
