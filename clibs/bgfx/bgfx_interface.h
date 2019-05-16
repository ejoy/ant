#pragma once

#include <lua.h>
#include <lauxlib.h>
#include <bgfx/c99/bgfx.h>
#include "simplelock.h"

static bgfx_interface_vtbl_t* bgfx_inf_ = 0;
static spinlock_t             bgfx_inf_lock;

static void init_interface(lua_State* L) {
	atom_spinlock(&bgfx_inf_lock);
	if (bgfx_inf_) {
		atom_spinunlock(&bgfx_inf_lock);
		return;
	}
	if (LUA_TFUNCTION != lua_getfield(L, LUA_REGISTRYINDEX, "BGFX_GET_INTERFACE")) {
		atom_spinunlock(&bgfx_inf_lock);
		luaL_error(L, "BGFX_GET_INTERFACE is missing.");
		return;
	}
	lua_CFunction fn = lua_tocfunction(L, -1);
	if (!fn) {
		atom_spinunlock(&bgfx_inf_lock);
		luaL_error(L, "BGFX_GET_INTERFACE is not a C function.");
		return;
	}
	bgfx_inf_ = ((PFN_BGFX_GET_INTERFACE)fn)(BGFX_API_VERSION);
	if (!bgfx_inf_) {
		atom_spinunlock(&bgfx_inf_lock);
		luaL_error(L, "BGFX_API_VERSION mismatch.");
		return;
	}
	lua_pop(L, 1);
	atom_spinunlock(&bgfx_inf_lock);
}

#define BGFX(api) bgfx_inf_->api
