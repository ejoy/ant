#include <stdio.h>
#include <lua.hpp>
#include <stdint.h>
#include <imgui.h>
#include <functional>

#include "imgui_window.h"
#include "luaref.h"

#define WINDOW_EVENTS "WINDOW_EVENTS"

enum class ANT_WINDOW {
	VIEWID = 2,
};

class events {
public:
	typedef std::function<void(lua_State*)> call_t;

	events(lua_State* L, lua_State* luastate)
		: reference(luaref_init(L))
		, luastate(luastate)
	{}
	~events() {
		luaref_close(reference);
	}
	void init(lua_State* L, int idx) {
		luaL_checktype(L, 1, LUA_TTABLE);
		ref_function(L, idx, "viewid", ANT_WINDOW::VIEWID);
	}
	void call(ANT_WINDOW eid, size_t argn, size_t retn) {
		luaref_get(reference, luastate, (int)eid);
		lua_insert(luastate, -1 - (int)argn);
		lua_call(luastate, (int)argn, (int)retn);
	}
	bool invoke(call_t f) {
		lua_State* L = luastate;
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
private:
	void ref_function(lua_State* L, int idx, const char* funcname, ANT_WINDOW eid) {
		if (lua_getfield(L, idx, funcname) != LUA_TFUNCTION) {
			luaL_error(L, "Missing %s", funcname);
		}
		if ((int)eid != luaref_ref(reference, L)) {
			luaL_error(L, "ID %d does not match", (int)eid);
		}
	}
	static int errhandler(lua_State* L) {
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
	static void errfunc(const char* msg) {
		lua_writestringerror("%s\n", msg);
	}
	static int function_call(lua_State* L) {
		call_t& f = *(call_t*)lua_touserdata(L, 1);
		f(L);
		return 0;
	}
	luaref reference;
	lua_State* luastate;
};

static events* get_events() {
	lua_State* L = (lua_State*)ImGui::GetIO().UserData;
	if (lua_getfield(L, LUA_REGISTRYINDEX, WINDOW_EVENTS) != LUA_TUSERDATA) {
		luaL_error(L, "Can't find window_callback.");
		return 0;
	}
	events* e = (events*)lua_touserdata(L, -1);
	lua_pop(L, 1);
	return e;
}

int window_event_viewid() {
	events* e = get_events();
	int viewid = 0;
	e->invoke([&](lua_State* L) {
		e->call(ANT_WINDOW::VIEWID, 0, 1);
		viewid = (int)luaL_checkinteger(L, -1);
	});
	return viewid;
}

void window_register(lua_State *L, int idx) {
	events* e = (events*)lua_newuserdatauv(L, sizeof(events), 1);
	lua_State* luastate = lua_newthread(L);
	lua_setiuservalue(L, -2, 1);
	lua_setfield(L, LUA_REGISTRYINDEX, WINDOW_EVENTS);
	new (e) events(L, luastate);
	e->init(L, idx);
}
