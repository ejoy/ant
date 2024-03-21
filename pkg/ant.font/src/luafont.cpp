#include <lua.hpp>
#include "../bgfx/bgfx_interface.h"
#include "fastio.h"

extern "C" {
#include "luabgfx.h"
#include "font_manager.h"
#include "truetype.h"
}

#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <assert.h>
#include <ctype.h>

static struct font_manager* 
getF(lua_State *L){
    return (struct font_manager*)lua_touserdata(L, lua_upvalueindex(1));
}

static int
lsubmit(lua_State *L){
	struct font_manager *F = getF(L);
	font_manager_flush(F);
	return 0;
}

static int
ltexture(lua_State *L) {
	struct font_manager *F = getF(L);
	uint16_t texture = font_manager_texture(F);
	lua_pushinteger(L, texture);
	return 1;
}

static int
limport(lua_State *L) {
	struct font_manager *F = getF(L);
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	void* fontdata = lua_touserdata(L, 1);
	font_manager_import(F, fontdata);
	return 0;
}

static int
lname(lua_State *L) {
	struct font_manager *F = getF(L);
	const char* family = luaL_checkstring(L, 1);
	const int fontid = font_manager_addfont_with_family(F, family);
	if (fontid > 0){
		lua_pushinteger(L, fontid);
		return 1;
	}
	return 0;
}

static int
initfont(lua_State *L) {
	switch (lua_type(L, 2)) {
	case LUA_TUSERDATA:
		lua_pushlightuserdata(L, lua_touserdata(L, 2));
		lua_replace(L, 2);
		break;
	case LUA_TLIGHTUSERDATA:
		break;
	default:
		luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
		break;
	}
	lua_settop(L, 2);
	luaL_Reg l[] = {
		{ "texture",			ltexture },
		{ "import",				limport },
		{ "name",				lname },
		{ "submit",				lsubmit },
		{ NULL, 				NULL },
	};
	lua_pushinteger(L, FONT_MANAGER_TEXSIZE);
	lua_setfield(L, 1, "fonttexture_size");
	luaL_setfuncs(L, l, 1);
	lua_settop(L, 1);
	return 1;
}

extern "C"
int luaopen_font(lua_State *L) {
	luaL_checkversion(L);
	lua_newtable(L);
	lua_newtable(L);
	lua_pushcfunction(L, initfont);
	lua_setfield(L, -2, "__call");
	lua_setmetatable(L, -2);
	return 1;
}

static int
luavm_init(lua_State *L) {
	luaL_openlibs(L);
	const char* data = (const char*)lua_touserdata(L, 1);
	size_t size = (size_t)lua_tointeger(L, 2);
	const char* chunkname = (const char*)lua_touserdata(L, 3);
	if (luaL_loadbuffer(L, data, size, chunkname) != LUA_OK) {
		return lua_error(L);
	}
	lua_call(L, 0, 0);
	return 0;
}

static int
fontm_init(lua_State *L) {
	struct font_manager* F = (struct font_manager *)lua_newuserdatauv(L, font_manager_sizeof(), 0);
	auto boot = getmemory(L, 1);
	lua_State* managerL = luaL_newstate();
	if (!managerL) {
		return luaL_error(L, "not enough memory");
	}
	lua_pushcfunction(managerL, luavm_init);
	lua_pushlightuserdata(managerL, (void*)boot.data());
	lua_pushinteger(managerL, (lua_Integer)boot.size());
	lua_pushlightuserdata(managerL, (void*)luaL_checkstring(L, 2));
	if (lua_pcall(managerL, 3, 0, 0) != LUA_OK) {
		lua_pushstring(L, lua_tostring(managerL, -1));
		lua_close(managerL);
		return lua_error(L);
	}
	font_manager_init(F, managerL);
	return 1;
}

static int
fontm_shutdown(lua_State *L) {
	struct font_manager* F = (struct font_manager*)lua_touserdata(L, 1);
	void* managerL = font_manager_shutdown(F);
	if (managerL) {
		lua_close((lua_State*)managerL);
	}
	return 0;
}

extern "C"
int luaopen_font_manager(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init", fontm_init },
		{ "shutdown", fontm_shutdown },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
