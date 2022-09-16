#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>

#define EVENT_QUEUE_SIZE 0x8000

static short int g_eventqueue[EVENT_QUEUE_SIZE] = { 0 };
static short int g_ptr = 0;

static int
levent_push(lua_State *L) {
	int e = luaL_checkinteger(L, 1);
	if (e == 0 || e > 0x7fff || e < -0x7ffff)
		return luaL_error(L, "Invalid event %d", e);
	int next = (g_ptr + 1) % EVENT_QUEUE_SIZE;
	g_eventqueue[next] = 0;
	g_eventqueue[g_ptr] = e;
	g_ptr = next;
	return 0;
}

static int
levent_pop(lua_State *L) {
	int ptr = lua_tointeger(L, lua_upvalueindex(1));
	int e = g_eventqueue[ptr];
	if (e == 0)
		return 0;
	int next = (ptr + 1) % EVENT_QUEUE_SIZE;
	lua_pushinteger(L, next);
	lua_replace(L, lua_upvalueindex(1));
	lua_pushinteger(L, e);
	return 1;
}

LUAMOD_API int
luaopen_textureman_client(lua_State *L) {
	luaL_checkversion(L);
	lua_newtable(L);
	lua_pushinteger(L, 0);
	lua_pushcclosure(L, levent_pop, 1);
	lua_setfield(L, -2, "event_pop");

	return 1;
}

LUAMOD_API int
luaopen_textureman_server(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "event_push", levent_push },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);	

	return 1;
}
