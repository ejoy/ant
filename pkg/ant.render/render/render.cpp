#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"

extern "C"{
	#include "math3d.h"
	#include "math3dfunc.h"
	#include "material.h"
}

#include "lua.hpp"
#include "luabgfx.h"
#include <bgfx/c99/bgfx.h>
#include <cstdint>
#include <cassert>
#include <array>
#include <vector>
#include <functional>
#include <unordered_map>
#include <memory.h>
#include <string.h>
#include <algorithm>

struct transform {
	uint32_t tid;
	uint32_t stride;
};

constexpr size_t MAX_MATERIAL_TYPE_COUNT = (offsetof(ecs::render_object, mat_ppoq) - offsetof(ecs::render_object, mat_def))/sizeof(intptr_t)+1;

using obj_transforms = std::unordered_map<const ecs::render_object*, transform>;
static inline transform
update_transform(struct ecs_world* w, const ecs::render_object *ro, obj_transforms &trans){
	auto it = trans.find(ro);
	if (it == trans.end()){
		const math_t wm = ro->worldmat;
		assert(math_valid(w->math3d->M, wm) && !math_isnull(wm) && "Invalid world mat");
		const float * v = math_value(w->math3d->M, wm);
		const int num = math_size(w->math3d->M, wm);
		transform t;
		bgfx_transform_t bt;
		t.tid = w->bgfx->encoder_alloc_transform(w->holder->encoder, &bt, (uint16_t)num);
		t.stride = num;
		memcpy(bt.data, v, sizeof(float)*16*num);
		it = trans.insert(std::make_pair(ro, t)).first;
	}

	return it->second;
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
get_material(const ecs::render_object* ro, size_t midx){
	assert(midx < MAX_MATERIAL_TYPE_COUNT);
	return (struct material_instance*)(*(&ro->mat_def + midx));
}

static void
draw(lua_State *L, struct ecs_world *w, const ecs::render_object *ro, bgfx_view_id_t viewid, size_t midx, obj_transforms &trans){
	if (mesh_submit(w, ro)){
		auto t = update_transform(w, ro, trans);
		w->bgfx->encoder_set_transform_cached(w->holder->encoder, t.tid, t.stride);
		auto mi = get_material(ro, midx);
		apply_material_instance(L, mi, w);

		const uint8_t discardflags = BGFX_DISCARD_ALL; //ro->discardflags;
		const auto prog = material_prog(L, mi);
		w->bgfx->encoder_submit(w->holder->encoder, viewid, prog, ro->depth, discardflags);
	}
}

using matrix_array = std::vector<math_t>;
using group_matrices = std::unordered_map<int, matrix_array>;
struct obj_data {
	const ecs::render_object* obj;
	const matrix_array* mats;
#if defined(_MSC_VER) && defined(_DEBUG)
	uint64_t id;
#endif
};

using objarray = std::vector<obj_data>;

static inline transform
update_hitch_transform(struct ecs_world *w, const ecs::render_object *ro, const matrix_array& worldmats, obj_transforms &trans_cache){
	auto it = trans_cache.find(ro);
	if (trans_cache.end() == it){
		transform t;
		t.stride = math_size(w->math3d->M, ro->worldmat);
		const auto nummat = worldmats.size();
		const auto num = nummat * t.stride;
		bgfx_transform_t trans;
		t.tid = w->bgfx->encoder_alloc_transform(w->holder->encoder, &trans, (uint16_t)num);
		for (size_t i=0; i<nummat; ++i){
			math_t r = math_ref(w->math3d->M, trans.data+i*t.stride*16, MATH_TYPE_MAT, t.stride);
			math3d_mul_matrix_array(w->math3d->M, worldmats[i], ro->worldmat, r);
		}

		it = trans_cache.insert(std::make_pair(ro, t)).first;
	}

	return it->second;
}

static void
draw_objs(lua_State *L, struct ecs_world *w, const ecs::render_args& ra, const objarray &objs, obj_transforms &trans){
	for (const auto &od : objs){
		auto mi = get_material(od.obj, ra.material_index);
		if (mi && mesh_submit(w, od.obj)) {
			apply_material_instance(L, mi, w);
			const auto prog = material_prog(L, mi);

			transform t;
			if (od.mats){
				t = update_hitch_transform(w, od.obj, *od.mats, trans);
				for (int i=0; i<od.mats->size()-1; ++i) {
					w->bgfx->encoder_set_transform_cached(w->holder->encoder, t.tid, t.stride);
					w->bgfx->encoder_submit(w->holder->encoder, ra.viewid, prog, od.obj->depth, BGFX_DISCARD_TRANSFORM);
					t.tid += t.stride;
				}
			} else {
				t = update_transform(w, od.obj, trans);
			}

			w->bgfx->encoder_set_transform_cached(w->holder->encoder, t.tid, t.stride);
			w->bgfx->encoder_submit(w->holder->encoder, ra.viewid, prog, od.obj->depth, BGFX_DISCARD_ALL);
		}
	}
}

static inline void
add_obj(struct ecs_world* w, cid_t vv_id, int index, const matrix_array* mats, objarray &objs){
	const ecs::render_object* obj = (const ecs::render_object*)entity_sibling(w->ecs, vv_id, index, ecs_api::component<ecs::render_object>::id);
#if defined(_MSC_VER) && defined(_DEBUG)
	ecs::eid id = (ecs::eid)entity_sibling(w->ecs, vv_id, index, ecs_api::component<ecs::eid>::id);
	objs.emplace_back(obj_data{ obj, mats, id });
#else
	objs.emplace_back(obj_data{ obj, mats });
#endif
}

static int
lsubmit(lua_State *L) {
	auto w = getworld(L);

	group_matrices groups;
	for (auto e : ecs_api::select<ecs::view_visible, ecs::hitch, ecs::scene>(w->ecs)){
		const auto &h = e.get<ecs::hitch>();
		const auto &s = e.get<ecs::scene>();
		if (h.group != 0){
			groups[h.group].push_back(s.worldmat);
		}
	}

	obj_transforms trans;

	for (auto a : ecs_api::select<ecs::render_args>(w->ecs)){
		const auto& ra = a.get<ecs::render_args>();

		objarray objs;
		
		const cid_t vv_id = ecs_api::component<ecs::view_visible>::id;
		for (int i=0; entity_iter(w->ecs, vv_id, i); ++i){
			if (entity_sibling(w->ecs, vv_id, i, ra.queue_visible_id) &&
				!entity_sibling(w->ecs, vv_id, i, ra.queue_cull_id)){
				add_obj(w, vv_id, i, nullptr, objs);
			}
		}
		for (auto const& [groupid, mats] : groups) {
			int gids[] = {groupid};
			ecs_api::group_enable<ecs::hitch_tag>(w->ecs, gids);
			const cid_t h_id = ecs_api::component<ecs::hitch_tag>::id;
			for (int i=0; entity_iter(w->ecs, h_id, i); ++i){
				if (entity_sibling(w->ecs, h_id, i, ra.queue_visible_id)){
					add_obj(w, h_id, i, &mats, objs);
				}
			}
		}

		std::sort(std::begin(objs), std::end(objs), [](const auto &lhs, const auto &rhs){
			return lhs.obj->render_layer < rhs.obj->render_layer;
		});
		draw_objs(L, w, ra, objs, trans);
	}
	return 0;
}

static int
ldraw(lua_State *L) {
	auto w = getworld(L);
	const cid_t draw_tagid = (cid_t)luaL_checkinteger(L, 1);
	const bgfx_view_id_t viewid = (bgfx_view_id_t)luaL_checkinteger(L, 2);
	const int material_index = (int)luaL_checkinteger(L, 3);
	obj_transforms trans;
	for (int i=0; entity_iter(w->ecs, draw_tagid, i); ++i){
		const auto ro = (ecs::render_object*)entity_sibling(w->ecs, draw_tagid, i, ecs_api::component<ecs::render_object>::id);
		if (ro == nullptr)
			return luaL_error(L, "id:%d is not a render_object entity");
		
		draw(L, w, ro, viewid, material_index, trans);
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