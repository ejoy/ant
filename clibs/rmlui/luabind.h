#pragma once

#include <lua.hpp>
#include <functional>

namespace luabind {
	typedef std::function<void(lua_State*)> call_t;
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
	inline int function_call(lua_State* L) {
		call_t& f = *(call_t*)lua_touserdata(L, 1);
		f(L);
		return 0;
	}
	template <typename T>
	struct global {
		static inline T v = T();
	};
	inline void init(lua_State* L) {
		if (global<lua_State*>::v) {
			return;
		}
		global<lua_State*>::v = lua_newthread(L);
		lua_setfield(L, LUA_REGISTRYINDEX, "LUABIND_THREAD");
	}
	inline bool invoke(call_t f) {
		lua_State* L = global<lua_State*>::v;
		if (!lua_checkstack(L, 3)) {
			errfunc("stack overflow");
			return false;
		}
		lua_pushcfunction(L, errhandler);
		lua_pushcfunction(L, function_call);
		lua_pushlightuserdata(L, &f);
		int r = lua_pcall(L, 1, 0, -3);
		if (r == LUA_OK) {
			lua_pop(L, 1);
			return true;
		}
		errfunc(lua_tostring(L, -1));
		lua_pop(L, 2);
		return false;
	}
}
