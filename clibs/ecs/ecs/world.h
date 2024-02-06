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
struct queue_container;
struct submit_cache;

struct bgfx_encoder_holder {
	struct bgfx_encoder_s* encoder;
};

struct cull_cached;

struct ecs_world {
	struct ecs_context*           ecs;
	struct bgfx_interface_vtbl*   bgfx;
	struct math3d_api*            math3d;
	struct bgfx_encoder_holder*   holder;
	struct cull_cached*           cull_cached;
	struct render_material*       R;
	uint64_t                      frame;
	struct queue_container*       Q;
	struct submit_cache*          submit_cache;
	uint64_t                      unused0;
	uint64_t                      unused1;
	uint64_t                      unused2;
};

static inline struct ecs_world* getworld(lua_State* L) {
#if !defined(NDEBUG)
	luaL_checktype(L, lua_upvalueindex(1), LUA_TUSERDATA);
	if (sizeof(struct ecs_world) > lua_rawlen(L, lua_upvalueindex(1))) {
		luaL_error(L, "invalid ecs_world");
		return NULL;
	}
#endif
	return (struct ecs_world*)lua_touserdata(L, lua_upvalueindex(1));
}
