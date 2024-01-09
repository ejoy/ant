#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include "../bgfx/bgfx_interface.h"
#include "luabgfx.h"

#include "font_manager.h"

#include "truetype.h"

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
	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	luaL_Reg l[] = {
		{ "texture",			ltexture },
		{ "import",				limport },
		{ "name",				lname },
		{ "submit",				lsubmit },
		{ NULL, 				NULL },
	};
	lua_settop(L, 2);
	lua_pushinteger(L, FONT_MANAGER_TEXSIZE);
	lua_setfield(L, 1, "fonttexture_size");
	luaL_setfuncs(L, l, 1);
	lua_settop(L, 1);
	return 1;
}

LUAMOD_API int
luaopen_font(lua_State *L) {
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
	const char* boot = (const char*)lua_touserdata(L, 1);
	if (luaL_loadstring(L, boot) != LUA_OK) {
		return lua_error(L);
	}
	lua_call(L, 0, 0);
	return 0;
}

static lua_State*
luavm_create(lua_State *L, const char* boot) {
	lua_State* vL = luaL_newstate();
	if (!vL) {
		luaL_error(L, "not enough memory");
		return NULL;
	}
	lua_pushcfunction(vL, luavm_init);
	lua_pushlightuserdata(vL, (void*)boot);
	if (lua_pcall(vL, 1, 0, 0) != LUA_OK) {
		lua_pushstring(L, lua_tostring(vL, -1));
		lua_close(vL);
		lua_error(L);
		return NULL;
	}
	return vL;
}

static int
fontm_init(lua_State *L) {
	struct font_manager *F = (struct font_manager*)lua_touserdata(L, lua_upvalueindex(1));
	const char* boot = luaL_checkstring(L, 1);
	font_manager_init_lua(F, luavm_create(L, boot));
	lua_pushlightuserdata(L, F);
	return 1;
}

static int
fontm_shutdown(lua_State *L) {
	struct font_manager *F = (struct font_manager*)lua_touserdata(L, lua_upvalueindex(1));
	void* managerL = font_manager_release_lua(F);
	if (managerL) {
		lua_close(managerL);
	}
	return 0;
}

LUAMOD_API int
luaopen_font_manager(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init", fontm_init },
		{ "shutdown", fontm_shutdown },
		{ NULL, NULL },
	};
	luaL_newlibtable(L, l);
	struct font_manager * F = (struct font_manager *)lua_newuserdatauv(L, sizeof(*F), 0);
	font_manager_init(F);
	luaL_setfuncs(L, l, 1);
	return 1;
}
