#pragma once

#if defined(__cplusplus)
#	include <lua.hpp>
#else
#	include <lua.h>
#	include <lauxlib.h>
#endif

struct ecs_context;
struct bgfx_interface_vtbl_t;
struct bgfx_encoder_t;
struct math3d_api;

struct bgfx_encoder_holder {
	struct bgfx_encoder_t* encoder;
};

struct ecs_world {
	struct ecs_context*           ecs;
	struct bgfx_interface_vtbl_t* bgfx;
	struct math3d_api*            math3d;
	struct bgfx_encoder_holder*   encoder;
};

static inline struct ecs_world* getworld(lua_State* L, int idx) {
	size_t sz = 0;
	struct ecs_world* ctx = (struct ecs_world*)luaL_checklstring(L, idx, &sz);
	if (sizeof(struct ecs_world) > sz) {
		luaL_error(L, "invalid ecs_world");
		return NULL;
	}
	return ctx;
}
