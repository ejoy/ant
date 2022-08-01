#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"
#include "math3d.h"
#include "lua.hpp"

extern "C"{
	#include "material.h"
}

#include "lua2struct.h"
#include "luabgfx.h"
#include <bgfx/c99/bgfx.h>
#include <cstdint>
#include <cassert>

#define MAX_MATERIAL_INSTANCE_SIZE 8
static_assert(offsetof(ecs::render_object, mat_csm4) - offsetof(ecs::render_object, mat_mq) == sizeof(int64_t) * (MAX_MATERIAL_INSTANCE_SIZE-1), "Invalid material data size");

//TODO: we should cache transform update by entity id
static inline void
update_transform(struct ecs_world* w, math_t wm){
	const float * v = math_value(w->math3d->M, wm);
	const int num = math_size(w->math3d->M, wm);
	w->bgfx->set_transform(v, num);
}

static const cid_t surface_stages[] = {
	(cid_t)ecs_api::component<ecs::foreground>::id,
	(cid_t)ecs_api::component<ecs::opacity>::id,
	(cid_t)ecs_api::component<ecs::background>::id,
	(cid_t)ecs_api::component<ecs::translucent>::id,
	(cid_t)ecs_api::component<ecs::decal_stage>::id,
	(cid_t)ecs_api::component<ecs::ui_stage>::id,
};

static void
mesh_submit(struct ecs_world* w, ecs::render_object* ro){
	const uint16_t vbtype = (ro->vb_handle>>16) & 0xffff;
	switch (vbtype){
		case BGFX_HANDLE_VERTEX_BUFFER:	w->bgfx->set_vertex_buffer(0, bgfx_vertex_buffer_handle_t{(uint16_t)ro->vb_handle}, ro->vb_start, ro->vb_num); break;
		case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER_TYPELESS:	//walk through
		case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER: w->bgfx->set_dynamic_vertex_buffer(0, bgfx_dynamic_vertex_buffer_handle_t{(uint16_t)ro->vb_handle}, ro->vb_start, ro->vb_num); break;
		default: assert(false && "Invalid vertex buffer type");
	}

	if (ro->ib_num > 0){
		const uint16_t ibtype = (ro->ib_handle>>16) & 0xffff;
		switch (ibtype){
			case BGFX_HANDLE_INDEX_BUFFER: w->bgfx->set_index_buffer(bgfx_index_buffer_handle_t{(uint16_t)ro->ib_handle}, ro->ib_start, ro->ib_num); break;
			case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER:	//walk through
			case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER_32: w->bgfx->set_dynamic_index_buffer(bgfx_dynamic_index_buffer_handle_t{(uint16_t)ro->ib_handle}, ro->ib_start, ro->ib_num); break;
			default: assert(false && "ib_num == 0 and handle is not valid"); break;
		}
	}
}

static inline struct material_instance*
get_material(const ecs::render_object* ro, int midx){
	return (struct material_instance*)(*(&ro->mat_mq + midx));
}

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
		if (midx >= MAX_MATERIAL_INSTANCE_SIZE){
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
						auto mi = get_material(ro, midx);
						apply_material_instance(L, mi, w, texture_index);

						mesh_submit(w, ro);

						const uint8_t discardflags = BGFX_DISCARD_ALL; //ro->discardflags;
						const auto prog = material_prog(L, mi);
						w->bgfx->submit(viewid, prog, ro->depth, discardflags);
					}
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