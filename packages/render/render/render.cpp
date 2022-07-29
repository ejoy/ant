#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"
#include "math3d.h"
#include "lua.hpp"

extern "C"{
	#include "material.h"
}
#include "mesh.h"

#include "lua2struct.h"
#include "luabgfx.h"
#include <bgfx/c99/bgfx.h>
#include <cstdint>
#include <cassert>

enum filter_stages : uint16_t {
	FS_foreground	= 0x01,
	FS_opaticy		= 0x02,
	FS_background	= 0x04,
	FS_trancluent	= 0x08,
	FS_decal_stage	= 0x10,
	FS_ui_stage		= 0x20,
	FS_count		= 6,
};

#define BGFX(_API)	w->bgfx->_API

struct material_instance;

struct queue_materials {
	enum queue_material_type : uint8_t {
		QMT_mainqueue = 0,
		QMT_predepth,
		QMT_scenedepth,
		QMT_pickup,
		QMT_csm1,
		QMT_csm2,
		QMT_csm3,
		QMT_csm4,
		QMT_count,
	};
	union {
		struct {
			struct material_instance* main;
			struct material_instance* predepth;
			struct material_instance* scenedepth;
			struct material_instance* pickup;
			struct material_instance* csm1;
			struct material_instance* csm2;
			struct material_instance* csm3;
			struct material_instance* csm4;
		};

		struct material_instance* materials[QMT_count];
	};

};

static_assert(sizeof(queue_materials::materials)/sizeof(queue_materials::materials[0]) == queue_materials::QMT_count);

//TODO: we should cache transform update by entity id
static inline void
update_transform(struct ecs_world* w, math_t wm){
	const float * v = math_value(w->math3d->M, wm);
	const int num = math_size(w->math3d->M, wm);
	BGFX(set_transform)(v, num);
}

static const cid_t surface_stages[] = {
	(cid_t)ecs_api::component<ecs::foreground>::id,
	(cid_t)ecs_api::component<ecs::opacity>::id,
	(cid_t)ecs_api::component<ecs::background>::id,
	(cid_t)ecs_api::component<ecs::translucent>::id,
	(cid_t)ecs_api::component<ecs::decal_stage>::id,
	(cid_t)ecs_api::component<ecs::ui_stage>::id,
};

static int
lsubmit(lua_State *L){
	auto w = getworld(L);
	ecs_api::context ecs {w->ecs};

	const int texture_index = 1;
	luaL_checktype(L, texture_index, LUA_TTABLE);

	for (auto a : ecs.select<ecs::render_args2>()){
		const auto& ra = a.get<ecs::render_args2>();
		const bgfx_view_id_t viewid = ra.viewid;
		const auto midx = ra.material_idx;
		if (midx >= queue_materials::QMT_count){
			luaL_error(L, "Invalid material_idx in render_args2:%d", midx);
		}
		const cid_t vs_id = ecs_api::component<ecs::view_visible>::id;
		for (int i=0; entity_iter(w->ecs, vs_id, i); ++i){
			const bool visible = entity_sibling(w->ecs, vs_id, i, ra.visible_id) &&
				!entity_sibling(w->ecs, vs_id, i, ra.cull_id);
			if (visible){
				for (auto ss : surface_stages){
					if (entity_sibling(w->ecs, vs_id, i, ss)){
						ecs::render_object* ro = (ecs::render_object*)entity_sibling(w->ecs, vs_id, i, ecs_api::component<ecs::render_object>::id);
						if (ro == nullptr)
							continue;

						update_transform(w, ro->worldmat);
						auto qm = (queue_materials*)ro->materials;
						auto mi = qm->materials[midx];
						apply_material_instance(L, mi, w, texture_index);
						const auto prog = material_prog(L, mi);
						mesh_submit((struct mesh*)ro->mesh, w);

						const uint8_t discardflags = BGFX_DISCARD_ALL; //ro->discardflags;
						w->bgfx->submit(viewid, prog, ro->depth, discardflags);
					}
				}
			}
		}
	}
	return 0;
}

static inline queue_materials* 
to_qm(lua_State *L, int idx) {
	return (queue_materials*)luaL_checkudata(L, idx, "ANT_QUEUE_MATERIALS");
}

static const char* s_queue_names[] = {
	"main_queue", "pre_depth_queue", "scene_depth_queue", "pickup_queue",
	"csm1_queue", "csm2_queue", "csm3_queue", "csm4_queue",
};

static inline int
queuename2idx(const char* n){
	for (int i=0; i<queue_materials::QMT_count; ++i){
		if (strcmp(n, s_queue_names[i]) == 0)
			return i;
	}
	return -1;
}

static inline int
check_material_idx(lua_State *L, int idx){
	const int argtype = lua_type(L, 2);
	int midx = -1;
	if (LUA_TSTRING == argtype){
		midx = queuename2idx(lua_tostring(L, idx));
	} else if (LUA_TNUMBER == argtype){
		midx = (int)lua_tointeger(L, idx)-1;
	} else {
		luaL_error(L, "Invalid argument type:%d", lua_typename(L, argtype));
	}

	if (midx < 0 || midx >= queue_materials::QMT_count){
		luaL_error(L, "Invalid material index:%d", midx);
	}

	return midx;
}

static int
lqm_set(lua_State *L){
	auto qm = to_qm(L, 1);
	const int midx = check_material_idx(L, 2);
	qm->materials[midx] = (struct material_instance*)luaL_checkudata(L, 3, "ANT_MATERIAL_INSTANCE");
	return 0;
}

static int
lqm_get(lua_State *L){
	auto qm = to_qm(L, 1);
	const int midx = check_material_idx(L, 2);
	lua_pushlightuserdata(L, qm->materials[midx]);
	return 1;
}

static int
lqm_num(lua_State *L){
	return queue_materials::QMT_count;
}

static int
lqueue_materials(lua_State *L){
	auto m = (queue_materials*)lua_newuserdatauv(L, sizeof(queue_materials), 0);
	memset(m, sizeof(*m), 0);
	if (luaL_newmetatable(L, "ANT_QUEUE_MATERIALS")){
		luaL_Reg l[] = {
			{"set", lqm_set},
			{"get", lqm_get},
			{"num", lqm_num},
			{NULL, NULL},
		};
		luaL_setfuncs(L, l, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);
	return 1;
}

extern "C" int
luaopen_render(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "submit", lsubmit},
		{ "queue_materials", lqueue_materials},
		{ nullptr, nullptr },
	};
	luaL_newlibtable(L,l);
	lua_pushnil(L);
	luaL_setfuncs(L,l,1);
	return 1;
}