#pragma once

#include <stdint.h>
#include <lua.h>
#include <lauxlib.h>

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

typedef int64_t math3d_id;

enum ComponentType
{
    TAG_SCENE_UPDATE = 1,
    COMPONENT_SCENE,
    COMPONENT_ENTITYID,
    TAG_SCENE_CHANGED, 
    TAG_VIEW_VISIBLE,
    COMPONENT_RENDER_OBJECT,
};

struct scene {
	int64_t     parent;
    math3d_id s;
    math3d_id r;
    math3d_id t;
    math3d_id mat;
    math3d_id worldmat;
    math3d_id updir;
    math3d_id aabb;
    math3d_id scene_aabb;
};

struct entity_id {
	int64_t id;
};

static inline struct ecs_world* 
getworld(lua_State* L, int idx) {
	size_t sz = 0;
	struct ecs_world* ctx = (struct ecs_world*)luaL_checklstring(L, idx, &sz);
	if (sizeof(struct ecs_world) > sz) {
		luaL_error(L, "invalid ecs_world");
		return NULL;
	}
	return ctx;
}
