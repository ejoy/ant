#pragma once

#include <lua.hpp>
#include <functional>

namespace luabind {
	typedef std::function<void(lua_State*)> call_t;
	typedef std::function<void(void)> callv_t;
	typedef std::function<void(const char*)> error_t;
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
	inline void errfunc(const char* msg) {
		// todo: use Rml log
		lua_writestringerror("%s\n", msg);
	}
	template <typename F>
	inline bool invoke(lua_State* L, F f, error_t err, int argn, lua_CFunction call) {
		if (!lua_checkstack(L, 3)) {
			err("stack overflow");
			lua_pop(L, argn);
			return false;
		}
		lua_pushcfunction(L, errhandler);
		lua_pushcfunction(L, call);
		lua_pushlightuserdata(L, &f);
		lua_rotate(L, -argn-3, 3);
		if (lua_pcall(L, 1 + argn, 0, lua_gettop(L) - argn - 2) != LUA_OK) {
			err(lua_tostring(L, -1));
			lua_pop(L, 2);
			return false;
		}
		lua_pop(L, 1);
		return true;
	}
	inline int function_call(lua_State* L) {
		call_t& f = *(call_t*)lua_touserdata(L, 1);
		f(L);
		return 0;
	}
	inline int function_callv(lua_State* L) {
		callv_t& f = *(callv_t*)lua_touserdata(L, 1);
		f();
		return 0;
	}
	inline bool invoke(lua_State* L, call_t f, error_t err = errfunc, int argn = 0) {
		return invoke(L, f, err, argn, function_call);
	}
	inline bool invoke(lua_State* L, callv_t f, error_t err = errfunc, int argn = 0) {
		return invoke(L, f, err, argn, function_callv);
	}
}
