#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>

#include "luaecs.h"
#include "component.h"
#include "scene.h"
#include "math3d.h"
#include "math3dfunc.h"

#define MATH3D(_FUNC, ...) world->math3d->_FUNC(world->math3d->LS, ...)
static int
lcull(lua_State *L){
	static uint16_t s_cull_tabs[16];
	const int numtab = (int)lua_rawlen(L, 2);
	if (numtab == 0){
		return 0;
	}

	if (numtab > sizeof(s_cull_tabs)/sizeof(s_cull_tabs[0])){
		return luaL_error(L, "Too many cull tabs");
	}

	for (int i=0; i<numtab; ++i){
		lua_geti(L, 2, i+1);
		s_cull_tabs[i] = (uint16_t)lua_tointeger(L, -1);
		lua_pop(L, 1);
	}

	struct ecs_world* world = getworld(L, 1);
	struct ecs_context* ecs = world->ecs;

	const math3d_id vpid = math3d_mark_id(L, world->math3d, 3);
	int vpmat_type = LINEAR_TYPE_NONE;
	const float* vpmat = math3d_value(world->math3d, vpid, &vpmat_type);
	if (vpmat_type != LINEAR_TYPE_MAT){
		luaL_error(L, "Invalid math3d id, need matrix type:%d", vpmat_type);
	}

	float planes[6][4];	float* pp[6] = {planes[0], planes[1], planes[2], planes[3], planes[4], planes[5]};
	math3d_frustum_planes(world->math3d->LS, vpmat, pp, math3d_homogeneous_depth());

	for (int i=0; entity_iter(ecs, COMPONENT_VIEW_VISIBLE, i); ++i) {
		if (entity_sibling(ecs, COMPONENT_VIEW_VISIBLE, i, COMPONENT_RENDER_OBJECT)) {
			struct scene * s = (struct scene *)entity_sibling(ecs, COMPONENT_VIEW_VISIBLE, i, COMPONENT_SCENE);
			if (s == NULL)
				continue;
			int type;
			const float* aabb = math3d_value(world->math3d, s->scene_aabb, &type);
			if (type == LINEAR_TYPE_NULL)
				continue;
			if (type != LINEAR_TYPE_MAT){
				return luaL_error(L, "Invalid scene_aabb, need matrix type:%d", type);
			}
			const int culled = math3d_frustum_intersect_aabb(world->math3d->LS, pp, aabb) < 0;
			component_id * id = (component_id *)entity_sibling(ecs, COMPONENT_VIEW_VISIBLE, i, COMPONENT_ID);
			if (id == NULL){
				return luaL_error(L, "Entity id not found");
			}

			if (culled){
				for (int ii=0; ii<numtab; ++ii){
					entity_enable_tag(ecs, COMPONENT_VIEW_VISIBLE, i, s_cull_tabs[ii]);
				}
			} else {
				for (int ii=0; ii<numtab; ++ii){
					entity_disable_tag(ecs, COMPONENT_VIEW_VISIBLE, i, s_cull_tabs[ii]);
				}
			}
			
		}
	}

	return 0;
}


LUAMOD_API int
luaopen_system_cull(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "cull", lcull },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
