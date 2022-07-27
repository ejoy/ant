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

static inline bool
entity_visible(struct ecs_world* w, cid_t vs_id, cid_t surfacestage_id, int index, const ecs::render_args2 &ra){
	return
		entity_sibling(w->ecs, vs_id, index, ra.visible_id) &&
		!entity_sibling(w->ecs, vs_id, index, ra.cull_id) &&
		entity_sibling(w->ecs, vs_id, index, surfacestage_id);
}
#define BGFX(_API)	w->bgfx->_API

struct material_instance;

struct queue_materials {
	enum filter_material_type : uint8_t {
		FMT_mainqueue = 0,
		FMT_predepth,
		FMT_scenedepth,
		FMT_pickup,
		FMT_csm1,
		FMT_csm2,
		FMT_csm3,
		FMT_csm4,
		FMT_count,
	};
	union {
		struct {
			struct material_instance* mq;
			struct material_instance* predepth;
			struct material_instance* scenedepth;
			struct material_instance* pickup;
			struct material_instance* csm1;
			struct material_instance* csm2;
			struct material_instance* csm3;
			struct material_instance* csm4;
		};

		struct material_instance* materials[FMT_count];
	};

};

static_assert(sizeof(queue_materials::materials)/sizeof(queue_materials::materials[0]) == queue_materials::FMT_count);

//TODO: we should cache transform update by entity id
static inline void
update_transform(struct ecs_world* w, math_t wm){
	const float * v = math_value(w->math3d->M, wm);
	const int num = math_size(w->math3d->M, wm);
	BGFX(set_transform)(v, num);
}

static queue_materials::filter_material_type
find_queue_material_type(uint32_t visibleid){
	switch (visibleid){
		case ecs_api::component<ecs::main_queue_visible>::id:
		return queue_materials::FMT_mainqueue;
		case ecs_api::component<ecs::pre_depth_queue_visible>::id:
		return queue_materials::FMT_predepth;
		case ecs_api::component<ecs::scene_depth_queue_visible>::id:
		return queue_materials::FMT_scenedepth;
		case ecs_api::component<ecs::pickup_queue_visible>::id:
		return queue_materials::FMT_pickup;
		case ecs_api::component<ecs::csm1_queue_visible>::id:
		return queue_materials::FMT_csm1;
		case ecs_api::component<ecs::csm2_queue_visible>::id:
		return queue_materials::FMT_csm1;
		case ecs_api::component<ecs::csm3_queue_visible>::id:
		return queue_materials::FMT_csm1;
		case ecs_api::component<ecs::csm4_queue_visible>::id:
		return queue_materials::FMT_csm1;
		default: assert(false && "Invalid visibleid"); return queue_materials::FMT_count;
	}
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
		const auto qmt = find_queue_material_type(ra.visible_id);
		const cid_t vs_id = ecs_api::component<ecs::view_visible>::id;
		for (int i=0; entity_iter(w->ecs, vs_id, i); ++i){
			for (auto ss : surface_stages){
				if (entity_visible(w, vs_id, ss, i, ra)){
					ecs::render_obj* ro = (ecs::render_obj*)entity_sibling(w->ecs, vs_id, i, ecs_api::component<ecs::render_obj>::id);
					if (ro == nullptr)
						continue;

					update_transform(w, ro->worldmat);
					auto qm = (queue_materials*)ro->materials;
					apply_material_instance(L, qm->materials[qmt], w, texture_index);
					mesh_submit((struct mesh*)ro->mesh, w);

					const uint8_t discardflags = BGFX_DISCARD_ALL; //ro->discardflags;
					const bgfx_view_id_t viewid = 0;
					assert(false && "need viewid");
					w->bgfx->submit(viewid, bgfx_program_handle_t{ro->prog}, ro->depth, discardflags);
				}
			}
		}
	}
	return 0;
}

extern "C" int
luaopen_render(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "submit", lsubmit},
		{ nullptr, nullptr },
	};
	luaL_newlibtable(L,l);
	lua_pushnil(L);
	luaL_setfuncs(L,l,1);
	return 1;
}