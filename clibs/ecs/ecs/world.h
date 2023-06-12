#pragma once

#if defined(__cplusplus)
#	include <lua.hpp>
#	include <utility>
#	include <cstdint>
#else
#	include <lua.h>
#	include <lauxlib.h>
#	include <stdint.h>
#endif

struct ecs_context;
struct bgfx_interface_vtbl;
struct bgfx_encoder_s;
struct math3d_api;
struct render_material;

struct bgfx_encoder_holder {
	struct bgfx_encoder_s* encoder;
};

struct cull_cached;
struct render_material;

struct ecs_world {
	struct ecs_context*           ecs;
	struct bgfx_interface_vtbl*   bgfx;
	struct math3d_api*            math3d;
	struct bgfx_encoder_holder*   holder;
	struct cull_cached*           cull_cached;
	struct render_material*       R;
	uint64_t                      frame;
	uintptr_t                     unused_0;
};

static inline struct ecs_world* getworld(lua_State* L) {
	size_t sz = 0;
	struct ecs_world* ctx = (struct ecs_world*)luaL_checklstring(L, lua_upvalueindex(1), &sz);
	if (sizeof(struct ecs_world) > sz) {
		luaL_error(L, "invalid ecs_world");
		return NULL;
	}
	return ctx;
}
