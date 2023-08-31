#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"

extern "C"{
	#include "math3d.h"
	#include "math3dfunc.h"
	#include "material.h"
	#include "programan.h"
	#include "render_material.h"
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

enum queue_type{
	qt_mat_def			= 0,
	qt_mat_pre_depth,
	qt_mat_pickup,
	qt_mat_csm,
	qt_mat_lightmap,
	qt_mat_outline,
	qt_mat_velocity,
	qt_count,
};

static constexpr uint8_t MAX_VISIBLE_QUEUE = 64;

using obj_transforms = std::unordered_map<uint64_t, transform>;
static inline transform
update_transform(struct ecs_world* w, const ecs::render_object *ro, const math_t& hwm, obj_transforms &trans){
	uint64_t tran_key = (uint64_t)ro ^ hwm.idx;
	auto it = trans.find(tran_key);
	if (it == trans.end()){
		const math_t wm = ro->worldmat;
		assert(math_valid(w->math3d->M, wm) && !math_isnull(wm) && "Invalid world mat");
		const int num = math_size(w->math3d->M, wm);
		transform t;
		bgfx_transform_t bt;
		t.tid = w->bgfx->encoder_alloc_transform(w->holder->encoder, &bt, (uint16_t)num);
		t.stride = num;
		if(hwm.idx == MATH_NULL.idx){
			const float * v = math_value(w->math3d->M, wm);
			memcpy(bt.data, v, sizeof(float)*16*num);
		}
		else{
			math_t r = math_ref(w->math3d->M, bt.data, MATH_TYPE_MAT, t.stride);
			math3d_mul_matrix_array(w->math3d->M, hwm, wm, r);			
		}
		it = trans.insert(std::make_pair(tran_key, t)).first;
	}
	return it->second;
}

#define INVALID_BUFFER_TYPE		UINT16_MAX
#define BUFFER_TYPE(_HANDLE)	(_HANDLE >> 16) & 0xffff

static inline bool is_indirect_draw(const ecs::render_object *ro){
	return ro->draw_num != 0 && ro->draw_num != UINT32_MAX;
}
static bool
mesh_submit(struct ecs_world* w, const ecs::render_object* ro, int vid, uint8_t mat_idx){
	if (ro->vb_num == 0 || ro->draw_num == 0)
		return false;

	const uint16_t ibtype = BUFFER_TYPE(ro->ib_handle);
	if (ibtype != INVALID_BUFFER_TYPE && ro->ib_num == 0)
		return false;

	const uint16_t vb_type = BUFFER_TYPE(ro->vb_handle);
	
	switch (vb_type){
		case BGFX_HANDLE_VERTEX_BUFFER:	w->bgfx->encoder_set_vertex_buffer(w->holder->encoder, 0, bgfx_vertex_buffer_handle_t{(uint16_t)ro->vb_handle}, ro->vb_start, ro->vb_num); break;
		case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER_TYPELESS:	//walk through
		case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER: w->bgfx->encoder_set_dynamic_vertex_buffer(w->holder->encoder, 0, bgfx_dynamic_vertex_buffer_handle_t{(uint16_t)ro->vb_handle}, ro->vb_start, ro->vb_num); break;
		default: assert(false && "Invalid vertex buffer type");
	}

	const uint16_t vb2_type = BUFFER_TYPE(ro->vb2_handle);
	if((vb2_type != INVALID_BUFFER_TYPE) && ((mat_idx == qt_mat_def) || (mat_idx == qt_mat_lightmap))){
		switch (vb2_type){
			case BGFX_HANDLE_VERTEX_BUFFER:	w->bgfx->encoder_set_vertex_buffer(w->holder->encoder, 1, bgfx_vertex_buffer_handle_t{(uint16_t)ro->vb2_handle}, ro->vb2_start, ro->vb2_num); break;
			case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER_TYPELESS:	//walk through
			case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER: w->bgfx->encoder_set_dynamic_vertex_buffer(w->holder->encoder, 1, bgfx_dynamic_vertex_buffer_handle_t{(uint16_t)ro->vb2_handle}, ro->vb2_start, ro->vb2_num); break;
			default: assert(false && "Invalid vertex buffer type");
		}
	}

	if (ro->ib_num > 0){
		switch (ibtype){
			case BGFX_HANDLE_INDEX_BUFFER: w->bgfx->encoder_set_index_buffer(w->holder->encoder, bgfx_index_buffer_handle_t{(uint16_t)ro->ib_handle}, ro->ib_start, ro->ib_num); break;
			case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER:	//walk through
			case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER_32: w->bgfx->encoder_set_dynamic_index_buffer(w->holder->encoder, bgfx_dynamic_index_buffer_handle_t{(uint16_t)ro->ib_handle}, ro->ib_start, ro->ib_num); break;
			default: assert(false && "Unknown index buffer type"); break;
		}
	}

	if(is_indirect_draw(ro)){
		const auto itb = bgfx_dynamic_vertex_buffer_handle_t{(uint16_t)ro->itb_handle};
		assert(BGFX_HANDLE_IS_VALID(itb));
		w->bgfx->encoder_set_instance_data_from_dynamic_vertex_buffer(w->holder->encoder, itb, 0, ro->draw_num);
	}
	return true;
}

static inline struct material_instance*
get_material(struct render_material * R, const ecs::render_object* ro, size_t midx){
	assert(midx < qt_count);
	//TODO: get all the materials by mask
	const uint64_t mask = 1ull << midx;
	void* mat[64] = {nullptr};
	render_material_fetch(R, ro->rm_idx, mask, mat);
	return (struct material_instance*)(mat[midx]);
}

using matrix_array = std::vector<math_t>;

static inline void
submit_draw(struct ecs_world*w, bgfx_view_id_t viewid, const ecs::render_object *obj, bgfx_program_handle_t prog, uint8_t discardflags){
	if(is_indirect_draw(obj)){
		const auto idb = bgfx_indirect_buffer_handle_t{(uint16_t)obj->idb_handle};
		assert(BGFX_HANDLE_IS_VALID(idb));
		w->bgfx->encoder_submit_indirect(w->holder->encoder, viewid, prog, idb, 0, obj->draw_num, obj->render_layer, discardflags);
	}else{
		w->bgfx->encoder_submit(w->holder->encoder, viewid, prog, obj->render_layer, discardflags);
	}
}

static inline void
draw_obj(lua_State *L, struct ecs_world *w, const ecs::render_args* ra, const ecs::render_object *obj, const matrix_array *mats, obj_transforms &trans){
	auto mi = get_material(w->R, obj, ra->material_index);
	
	if (nullptr == mi)
		return ;
	
	const auto prog = material_prog(L, mi);
	if (!BGFX_HANDLE_IS_VALID(prog) || !mesh_submit(w, obj, ra->viewid, ra->material_index))
		return ;

	apply_material_instance(L, mi, w);
	
	transform t;
	if (mats){
		for (int i=0; i<mats->size()-1; ++i) {
			t = update_transform(w, obj, (*mats)[i], trans);
			w->bgfx->encoder_set_transform_cached(w->holder->encoder, t.tid, t.stride);
			submit_draw(w, ra->viewid, obj, prog, BGFX_DISCARD_TRANSFORM);
		}
		t = update_transform(w, obj, mats->back(), trans);
	} else {
		t = update_transform(w, obj, MATH_NULL, trans);
	}

	w->bgfx->encoder_set_transform_cached(w->holder->encoder, t.tid, t.stride);
	submit_draw(w, ra->viewid, obj, prog, BGFX_DISCARD_ALL);
}

using group_queues = std::array<matrix_array, 64>;
using group_collection = std::unordered_map<int, group_queues>;
struct submit_cache{
	obj_transforms	transforms;

	//TODO: need more fine control of the cache
	group_collection	groups;

	struct render_args {
		const ecs::render_args* a;
		int queue_idx;
	};
	render_args ra[MAX_VISIBLE_QUEUE] = {0};
	uint8_t ra_count = 0;

	void clear(){
		transforms.clear();
		groups.clear();

		ra_count = 0;

#ifdef _DEBUG
		memset(ra, 0xdeaddead, sizeof(ra));
#endif //_DEBUG
	}
};

template<typename ObjType>
static bool obj_visible(const ObjType &o, uint64_t mask){
	return	(0 != (o.visible_masks & mask)) && 
			(0 == (o.cull_masks & mask));
}

template<typename ObjType>
static bool obj_queue_visible(const ObjType &o, uint64_t mask){
	return	(0 != (o.visible_masks & mask));
}

static inline int queue_idx(uint64_t mask){
	for (int ii=0; ii<64; ++ii){
		if (((UINT64_C(1) << ii) & mask) != 0){
			return ii;
		}
	}
	return -1;
}

static inline void
find_render_args(struct ecs_world *w, submit_cache &cc) {
	for (auto& r : ecs_api::array<ecs::render_args>(w->ecs)) {
		cc.ra[cc.ra_count++] = {&r, queue_idx(r.queue_mask)};
	}
}

//TODO: maybe move to another c module
static constexpr uint16_t MAX_EFK_HITCH = 256;
static inline void
submit_efk_obj(lua_State* L, struct ecs_world* w, const ecs::efk_object *eo, const matrix_array& mats, std::span<ecs::efk_hitch>& a_eh, int32_t &count){
	for (auto m : mats){
		if (count >= MAX_EFK_HITCH){
			luaL_error(L, "Too many hitch for efk object");
		}
		
		auto& eh = a_eh[count++];
		eh.handle 	= eo->handle;
		eh.hitchmat = m;
		eh.worldmat	= eo->worldmat;
	}
}

static int
lsubmit(lua_State *L) {
	auto w = getworld(L);

	static submit_cache cc;
	find_render_args(w, cc);

	// draw simple objects
	for (auto& e : ecs_api::select<ecs::view_visible, ecs::render_object>(w->ecs)) {
		for (uint8_t ii=0; ii<cc.ra_count; ++ii){
			const auto& ra = cc.ra[ii];
			const auto& obj = e.get<ecs::render_object>();
			if (obj_visible(obj, ra.a->queue_mask) || (is_indirect_draw(&obj) && obj_queue_visible(obj, ra.a->queue_mask))){
				draw_obj(L, w, ra.a, &obj, nullptr, cc.transforms);
			}
		}
	}

	// draw object which hanging on hitch node
	for (auto e : ecs_api::select<ecs::view_visible, ecs::hitch, ecs::scene>(w->ecs)) {
		const auto &h = e.get<ecs::hitch>();
		for (uint8_t ii=0; ii<cc.ra_count; ++ii){
			const auto &ra = cc.ra[ii];
			const auto queue_mask = ra.a->queue_mask;
			if (obj_visible(h, queue_mask)){
				const auto &s = e.get<ecs::scene>();
				if (h.group != 0){
					cc.groups[h.group][ra.queue_idx].push_back(s.worldmat);
				}
			}
		}
	}

	auto e = ecs_api::first_entity<ecs::efk_hitch_counter>(w->ecs);
	auto& ehc = e.get<ecs::efk_hitch_counter>();

	for (auto const& [groupid, g] : cc.groups) {
		int gids[] = {groupid};
		ecs_api::group_enable<ecs::hitch_tag>(w->ecs, gids);
		for (auto& e : ecs_api::select<ecs::hitch_tag>(w->ecs)) {
			for (uint8_t ii=0; ii<cc.ra_count; ++ii){
				const auto& ra = cc.ra[ii];
				const auto &mats = g[ra.queue_idx];
				if (!mats.empty()){
					auto ro = e.component<ecs::render_object>();
					if (ro && obj_queue_visible(*ro, ra.a->queue_mask)){
						draw_obj(L, w, ra.a, ro, &mats, cc.transforms);
					}

					const auto eo = e.component<ecs::efk_object>();
					
					if (eo && obj_queue_visible(*eo, ra.a->queue_mask)){
						auto a_eh = ecs_api::array<ecs::efk_hitch>(w->ecs);
						submit_efk_obj(L, w, eo, mats, a_eh, ehc.count);
					}
				}
			}
		}
	}

	cc.clear();
	return 0;
}

static int
lnull(lua_State *L){
	lua_pushlightuserdata(L, nullptr);
	return 1;
}

static int
lrm_dealloc(lua_State *L){
	auto w = getworld(L);
	const int index = (int)luaL_checkinteger(L, 1);
	render_material_dealloc(w->R, index);
	return 0;
}

static int
lrm_alloc(lua_State *L){
	auto w = getworld(L);
	lua_pushinteger(L, render_material_alloc(w->R));
	return 1;
}

static int
lrm_set(lua_State *L){
	auto w = getworld(L);
	const int index = (int)luaL_checkinteger(L, 1);
	if (index < 0){
		return luaL_error(L, "Invalid index:%d", index);
	}
	const int type = (int)luaL_checkinteger(L, 2);
	if (type < 0 || type > RENDER_MATERIAL_TYPE_MAX){
		luaL_error(L, "Invalid render_material type: %d, should be : 0 <= type <= %d", type, RENDER_MATERIAL_TYPE_MAX);
	}

	const int valuetype = lua_type(L, 3);
	if (valuetype != LUA_TLIGHTUSERDATA && valuetype != LUA_TNIL){
		luaL_error(L, "Set render_material material type should be lightuserdata:%s", lua_typename(L, 3));
	}
	const auto m = lua_touserdata(L, 3);

	render_material_set(w->R, index, type, m);
	return 0;
}

extern "C" int
luaopen_render_material(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "null",		lnull},
		{ "dealloc",	lrm_dealloc},
		{ "alloc",		lrm_alloc},
		{ "set",		lrm_set},

		{ nullptr, 		nullptr },
	};
	luaL_newlibtable(L,l);
	lua_pushnil(L);
	luaL_setfuncs(L,l,1);
	return 1;
}

static void
init_efk(struct ecs_world* w){
	for (uint16_t ii=0; ii<MAX_EFK_HITCH; ++ii){
		ecs_api::create_entity<ecs::efk_hitch>(w->ecs);
	}

	ecs_api::create_entity<ecs::efk_hitch_counter>(w->ecs, 0);
}

static void
remove_efk(struct ecs_world* w){
	for (auto &e : ecs_api::select<ecs::efk_hitch>(w->ecs)){
		e.enable_tag<ecs::REMOVED>();
	}

	auto e = ecs_api::first_entity<ecs::efk_hitch_counter>(w->ecs);
	e.enable_tag<ecs::REMOVED>();
}

static int
linit(lua_State *L){
	auto w = getworld(L);
	w->R = render_material_create();

	init_efk(w);
	return 1;
}

static int
lexit(lua_State *L){
	auto w = getworld(L);
	render_material_release(w->R);
	w->R = nullptr;

	remove_efk(w);
	return 0;
}

extern "C" int
luaopen_system_render(lua_State *L){
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init",			linit},
		{ "exit",			lexit},
		{ "render_submit", 	lsubmit},
		{ nullptr, 			nullptr },
	};
	luaL_newlibtable(L,l);
	lua_pushnil(L);
	luaL_setfuncs(L,l,1);
	return 1;
}