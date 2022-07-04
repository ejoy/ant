#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>

#include "luaecs.h"
#include "scene.h"

struct CullTabIDs{
	const char* name;
	uint16_t id;
};

// //TODO: should be a dynamic array
// struct CullTabIDs s_CullTabIDs[] = {
// 	{"main_queue_foreground_cull"}
// 	{"main_queue_opaticy_cull"},
// 	{"main_queue_tranclucent_cull"},
// 	{"main_queue_background_cull"},
// 	{"main_queue_decal_cull"},
// 	{"main_queue_ui_cull"},

// 	{"scene_depth_foreground_cull"}
// 	{"scene_depth_opaticy_cull"},
// 	{"scene_depth_tranclucent_cull"},
// 	{"scene_depth_background_cull"},

// 	{"pre_depth_queue_opaticy_cull"},

// 	{"pickup_queue_opaticy_cull"},
// 	{"pickup_queue_tranclucent_cull"},

// 	{"second_view_queue_foreground_cull"}
// 	{"second_view_queue_opaticy_cull"},
// 	{"second_view_queue_tranclucent_cull"},
// 	{"second_view_queue_background_cull"},
// 	{"second_view_queue_decal_cull"},
// 	{"second_view_queue_ui_cull"},
// };

// static inline uint16_t 
// to_tab_id(lua_State *L, const char* n){
// 	for (int i=0; i<sizeof(s_CullTabIDs)/sizeof(s_CullTabIDs[0]); ++i){
// 		if (strcmp(n, s_CullTabIDs[i].name) == 0)
// 			return s_CullTabIDs[i].id;
// 	}

// 	return luaL_error(L, "Invalid cull tab name:%s", n);
// }

static int
lcull(lua_State *L){
	static uint16_t s_MaxCullTabs[16];
	const int numtab = lua_rawlen(L, 2);
	if (numtab == 0){
		return 0;
	}

	if (numtab > sizeof(s_MaxCullTabs)/sizeof(s_MaxCullTabs[0])){
		return luaL_error(L, "Too many cull tabs");
	}

	for (int i=0; i<numtab; ++i){
		lua_geti(L, i+1);
		s_MaxCullTabs[i] = lua_tointegerx(L, -1);
		lua_pop(L, 1);
	}

	struct ecs_world* world = getworld(L, 1);
	struct ecs_context* ecs = world->ecs;

	const math3d_id vpid = math3d_mark_id(L, world->math, 3);
	int vpmat_type = LINEAR_TYPE_NONE;
	const float* vpmat = math3d_value(world->math, vpid, &vpmat_type);
	if (vpmat_type != LINEAR_TYPE_MAT){
		luaL_error(L, "Invalid math3d id, need matrix type:%d", vpmat_type);
	}

	float planes[6][4];
	math3d_frustum_planes(world->math->LS, vpmat, planes, math3d_homogeneous_depth());

	for (int i=0; entity_iter(ecs, TAG_VIEW_VISIBLE, i); ++i) {
		if (entity_sibling(ecs, TAG_VIEW_VISIBLE, i, COMPONENT_RENDER_OBJECT)) {
			struct scene * s = (struct scene *)entity_sibling(ecs, TAG_VIEW_VISIBLE, i, COMPONENT_SCENE);
			int type;
			const float* aabb = math3d_value(world->math, s->scene_aabb, &type);
			if (type != LINEAR_TYPE_MAT){
				luaL_error(L, "Invalid scene_aabb, need matrix type:%d", type);
			}
			if (math3d_frustum_intersect_aabb(world->math->LS, planes, aabb) < 0){
				struct entity_id * eid = (struct entity_id *)entity_sibling(ecs, TAG_VIEW_VISIBLE, i, COMPONENT_ENTITY_ID);
				for (int ii=0; ii<numtab; ++ii){
					entity_enable_tag(ecs, eid, i, s_MaxCullTabs[ii]);
				}
			}
		}
	}
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
