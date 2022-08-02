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
#include <vector>

enum queue_index_type : uint8_t{
	QIT_mainqueue = 0,
	QIT_predepth,
	QIT_scenedepth,
	QIT_pickup,
	QIT_csm1,
	QIT_csm2,
	QIT_csm3,
	QIT_csm4,
	QIT_lightmap,
	QIT_count,
};

#define MAX_MATERIAL_INSTANCE_SIZE 8
static_assert(offsetof(ecs::render_object, mat_lightmap) - offsetof(ecs::render_object, mat_mq) == sizeof(int64_t) * (QIT_count-1), "Invalid material data size");

//TODO: we should cache transform update by entity id
static inline void
update_transform(struct ecs_world* w, math_t wm){
	const float * v = math_value(w->math3d->M, wm);
	const int num = math_size(w->math3d->M, wm);
	w->bgfx->encoder_set_transform(w->holder->encoder, v, num);
}

#define INVALID_BUFFER_TYPE UINT16_MAX
#define BUFFER_TYPE(_HANDLE)	(_HANDLE >> 16) & 0xffff

static bool
mesh_submit(struct ecs_world* w, const ecs::render_object* ro){
	if (ro->vb_num == 0)
		return false;

	const uint16_t ibtype = BUFFER_TYPE(ro->ib_handle);
	if (ibtype != INVALID_BUFFER_TYPE && ro->ib_num == 0)
		return false;

	const uint16_t vbtype = BUFFER_TYPE(ro->vb_handle);
	switch (vbtype){
		case BGFX_HANDLE_VERTEX_BUFFER:	w->bgfx->encoder_set_vertex_buffer(w->holder->encoder, 0, bgfx_vertex_buffer_handle_t{(uint16_t)ro->vb_handle}, ro->vb_start, ro->vb_num); break;
		case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER_TYPELESS:	//walk through
		case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER: w->bgfx->encoder_set_dynamic_vertex_buffer(w->holder->encoder, 0, bgfx_dynamic_vertex_buffer_handle_t{(uint16_t)ro->vb_handle}, ro->vb_start, ro->vb_num); break;
		default: assert(false && "Invalid vertex buffer type");
	}

	if (ro->ib_num > 0){
		switch (ibtype){
			case BGFX_HANDLE_INDEX_BUFFER: w->bgfx->encoder_set_index_buffer(w->holder->encoder, bgfx_index_buffer_handle_t{(uint16_t)ro->ib_handle}, ro->ib_start, ro->ib_num); break;
			case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER:	//walk through
			case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER_32: w->bgfx->encoder_set_dynamic_index_buffer(w->holder->encoder, bgfx_dynamic_index_buffer_handle_t{(uint16_t)ro->ib_handle}, ro->ib_start, ro->ib_num); break;
			default: assert(false && "ib_num == 0 and handle is not valid"); break;
		}
	}

	return true;
}

static inline struct material_instance*
get_material(const ecs::render_object* ro, int qidx){
	return (struct material_instance*)(*(&ro->mat_mq + qidx));
}

static void
draw(lua_State *L, struct ecs_world *w, const ecs::render_object *ro, bgfx_view_id_t viewid, int queueidx, int texture_index){
	if (mesh_submit(w, ro)){
		update_transform(w, ro->worldmat);
		auto mi = get_material(ro, queueidx);
		apply_material_instance(L, mi, w, texture_index);

		const uint8_t discardflags = BGFX_DISCARD_ALL; //ro->discardflags;
		const auto prog = material_prog(L, mi);
		w->bgfx->encoder_submit(w->holder->encoder, viewid, prog, ro->depth, discardflags);
	}
}

using render_obj_array = std::vector<const ecs::render_object*>;
struct queue_stages {
	struct stage {
		cid_t id;
		render_obj_array objs;
	};
	stage	stages[6] = {
		{(cid_t)ecs_api::component<ecs::foreground>::id},
		{(cid_t)ecs_api::component<ecs::opacity>::id},
		{(cid_t)ecs_api::component<ecs::background>::id},
		{(cid_t)ecs_api::component<ecs::translucent>::id},
		{(cid_t)ecs_api::component<ecs::decal_stage>::id},
		{(cid_t)ecs_api::component<ecs::ui_stage>::id},
	};

	void clear(){
		for (auto &s : stages){
			s.objs.clear();
		}
	}
};

static queue_stages s_queue_stages;

static int
lsubmit(lua_State *L){
	auto w = getworld(L);
	ecs_api::context ecs {w->ecs};

	const int texture_index = 1;
	luaL_checktype(L, texture_index, LUA_TTABLE);
	for (auto a : ecs.select<ecs::render_args2>()){
		const auto& ra = a.get<ecs::render_args2>();
		const bgfx_view_id_t viewid = ra.viewid;
		const auto qidx = ra.queue_index;
		if (qidx >= MAX_MATERIAL_INSTANCE_SIZE){
			luaL_error(L, "Invalid queue_index in render_args2:%d", qidx);
		}
		s_queue_stages.clear();
		const cid_t vs_id = ecs_api::component<ecs::view_visible>::id;
		for (int i=0; entity_iter(w->ecs, vs_id, i); ++i){
			const bool visible = entity_sibling(w->ecs, vs_id, i, ra.visible_id) &&
				!entity_sibling(w->ecs, vs_id, i, ra.cull_id);
			if (visible){
				for (auto &s : s_queue_stages.stages){
					if (entity_sibling(w->ecs, vs_id, i, s.id)){
						const ecs::render_object* ro = (ecs::render_object*)entity_sibling(w->ecs, vs_id, i, ecs_api::component<ecs::render_object>::id);
						if (ro){
							s.objs.push_back(ro);
						}
					}
				}
			}
		}
		for (auto &qs : s_queue_stages.stages){
			for (auto &ro: qs.objs){
				draw(L, w, ro, viewid, qidx, texture_index);
			}
		}
	}
	return 0;
}

static const char* s_queuenames[QIT_count] = {
	"main_queue", "pre_depth_queue", "scene_depth_queue", "pickup_queue",
	"csm1_queue", "csm2_queue", "csm3_queue", "csm4_queue",
	"lightmap_queue",
};

static inline queue_index_type
to_queue_idx(lua_State *L, int index){
	const int t = lua_type(L, index);
	if (t == LUA_TSTRING){
		auto s = lua_tostring(L, index);
		for (int ii=0; ii<QIT_count; ++ii){
			if (strcmp(s_queuenames[ii], s) == 0){
				return (queue_index_type)ii;
			}
		}

		return QIT_count;
	} else if (t == LUA_TNUMBER){
		return (queue_index_type)lua_tointeger(L, index);
	} else if (t == LUA_TNIL){
		return QIT_mainqueue;
	}

	luaL_error(L, "Invalid type index: %d", index);
	return QIT_count;
}

static int
ldraw(lua_State *L){
	auto w = getworld(L);
	ecs_api::context ecs {w->ecs};
	const cid_t draw_tagid = (cid_t)luaL_checkinteger(L, 1);
	const bgfx_view_id_t viewid = (bgfx_view_id_t)luaL_checkinteger(L, 2);
	const int texture_index = 3;
	luaL_checktype(L, texture_index, LUA_TTABLE);
	const int queue_index = to_queue_idx(L, 4);
	for (int i=0; entity_iter(w->ecs, draw_tagid, i); ++i){
		const auto ro = (ecs::render_object*)entity_sibling(w->ecs, draw_tagid, i, ecs_api::component<ecs::render_object>::id);
		if (ro == nullptr)
			return luaL_error(L, "id:%d is not a render_object entity");
		
		draw(L, w, ro, viewid, queue_index, texture_index);
	}
	return 0;
}

static int
lnull(lua_State *L){
	lua_pushlightuserdata(L, nullptr);
	return 1;
}

extern "C" int
luaopen_render(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "submit", lsubmit},
		{ "draw",	ldraw},
		{ "null",	lnull},
		{ nullptr, nullptr },
	};
	luaL_newlibtable(L,l);
	lua_pushnil(L);
	luaL_setfuncs(L,l,1);
	return 1;
}