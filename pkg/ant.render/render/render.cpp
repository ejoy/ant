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

#include "queue.h"
#include "hash.h"

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

//using obj_transforms = std::unordered_map<uint64_t, transform>;
struct obj_transforms {
	static constexpr uint16_t MAX_CACHE = (16384-1);
	struct key {
		static uint16_t hash_idx(const component::render_object *ro, math_t m) {
			return (uint16_t)((hash64((uint64_t)ro^m.idx)) % obj_transforms::MAX_CACHE);
		}

		const component::render_object * ro;
		math_t m;
		uint16_t hidx;
	};

	key			keys[MAX_CACHE] = {{0}};
	transform	values[MAX_CACHE] = {{0}};

	bool check(const key& k, transform &v) const {
		const key& r = keys[k.hidx];
		if (r.ro == k.ro && r.m.idx == k.m.idx){
			v = values[k.hidx];
			return true;
		}
		return false;
	}

	void add(const key& k, const transform &v){
		values[k.hidx] = v;
		keys[k.hidx] = k;
	}

	void clear(){
		memset(keys, 0, sizeof(keys));
	}
};

static inline transform
update_transform(struct ecs_world* w, const component::render_object *ro, const math_t& hwm, obj_transforms &trans){
	auto key = obj_transforms::key{ro, hwm, obj_transforms::key::hash_idx(ro, hwm)};
	transform t;
	if (!trans.check(key, t)){
		const math_t wm = ro->worldmat;
		assert(math_valid(w->math3d->M, wm) && !math_isnull(wm) && "Invalid world mat");
		const int num = math_size(w->math3d->M, wm);

		bgfx_transform_t bt;
		t.tid = w->bgfx->encoder_alloc_transform(w->holder->encoder, &bt, (uint16_t)num);
		t.stride = num;
		if(math_isnull(hwm)){
			const float * v = math_value(w->math3d->M, wm);
			memcpy(bt.data, v, sizeof(float)*16*num);
		} else{
			math_t r = math_ref(w->math3d->M, bt.data, MATH_TYPE_MAT, t.stride);
			math3d_mul_matrix_array(w->math3d->M, hwm, wm, r);
		}

		trans.add(key, t);
	}

	return t;
}

#define INVALID_BUFFER_TYPE		UINT16_MAX
#define BUFFER_TYPE(_HANDLE)	(_HANDLE >> 16) & 0xffff

static inline bool indirect_draw_valid(const component::indirect_object *ido){
	return ido && ido->draw_num != 0 && ido->draw_num != UINT32_MAX;
}

template<typename ObjType>
static bool obj_visible(struct queue_container* Q, const ObjType &o, uint8_t qidx){
	return	queue_check(Q, o.visible_idx, qidx) &&
			!queue_check(Q, o.cull_idx, qidx);
}

static bool
mesh_submit(struct ecs_world* w, const component::render_object* ro,  int vid){
	const uint16_t vb_type = BUFFER_TYPE(ro->vb_handle);
	
	switch (vb_type){
		case BGFX_HANDLE_VERTEX_BUFFER:	w->bgfx->encoder_set_vertex_buffer(w->holder->encoder, 0, bgfx_vertex_buffer_handle_t{(uint16_t)ro->vb_handle}, ro->vb_start, ro->vb_num); break;
		case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER_TYPELESS:	//walk through
		case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER: w->bgfx->encoder_set_dynamic_vertex_buffer(w->holder->encoder, 0, bgfx_dynamic_vertex_buffer_handle_t{(uint16_t)ro->vb_handle}, ro->vb_start, ro->vb_num); break;
		default: assert(false && "Invalid vertex buffer type");
	}

	const uint16_t vb2_type = BUFFER_TYPE(ro->vb2_handle);
	if((vb2_type != INVALID_BUFFER_TYPE)){
		switch (vb2_type){
			case BGFX_HANDLE_VERTEX_BUFFER:	w->bgfx->encoder_set_vertex_buffer(w->holder->encoder, 1, bgfx_vertex_buffer_handle_t{(uint16_t)ro->vb2_handle}, ro->vb2_start, ro->vb2_num); break;
			case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER_TYPELESS:	//walk through
			case BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER: w->bgfx->encoder_set_dynamic_vertex_buffer(w->holder->encoder, 1, bgfx_dynamic_vertex_buffer_handle_t{(uint16_t)ro->vb2_handle}, ro->vb2_start, ro->vb2_num); break;
			default: assert(false && "Invalid vertex buffer type");
		}
	}

	if (ro->ib_num > 0){
		switch (BUFFER_TYPE(ro->ib_handle)){
			case BGFX_HANDLE_INDEX_BUFFER: w->bgfx->encoder_set_index_buffer(w->holder->encoder, bgfx_index_buffer_handle_t{(uint16_t)ro->ib_handle}, ro->ib_start, ro->ib_num); break;
			case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER:	//walk through
			case BGFX_HANDLE_DYNAMIC_INDEX_BUFFER_32: w->bgfx->encoder_set_dynamic_index_buffer(w->holder->encoder, bgfx_dynamic_index_buffer_handle_t{(uint16_t)ro->ib_handle}, ro->ib_start, ro->ib_num); break;
			default: assert(false && "Unknown index buffer type"); break;
		}
	}
	return true;
}

static inline struct material_instance*
get_material(struct render_material * R, uint32_t rmidx, size_t midx){
	//TODO: get all the materials by mask
	const uint64_t mask = 1ull << midx;
	void* mat[64] = {nullptr};
	render_material_fetch(R, rmidx, mask, mat);
	return (struct material_instance*)(mat[midx]);
}

using matrix_array = std::vector<math_t>;

static inline void
submit_draw(struct ecs_world*w, bgfx_view_id_t viewid, const component::render_object *obj, const component::indirect_object *iobj, bgfx_program_handle_t prog, uint8_t discardflags){
	if(indirect_draw_valid(iobj)){
		const auto idb = bgfx_indirect_buffer_handle_t{(uint16_t)iobj->idb_handle};
		assert(BGFX_HANDLE_IS_VALID(idb));
		w->bgfx->encoder_submit_indirect(w->holder->encoder, viewid, prog, idb, 0, iobj->draw_num, obj->render_layer, discardflags);
	}else{
		w->bgfx->encoder_submit(w->holder->encoder, viewid, prog, obj->render_layer, discardflags);
	}
}

//TODO: maybe move to another c module
static constexpr uint16_t MAX_EFK_HITCH = 256;
static inline void
submit_efk_obj(lua_State* L, struct ecs_world* w, const component::efk_object *eo, const matrix_array& mats){
	for (auto m : mats){
		if (entity_count(w->ecs, ecs::component_id<component::efk_hitch>) >= MAX_EFK_HITCH){
			luaL_error(L, "Too many 'efk_hitch' object");
		}
		auto *eh = (component::efk_hitch*)entity_component_temp(w->ecs, ecs::component_id<component::efk_hitch_tag>, ecs::component_id<component::efk_hitch>);
		eh->handle		= eo->handle;
		eh->hitchmat	= (uintptr_t)math_value(w->math3d->M, math3d_mul_matrix(w->math3d->M, m, eo->worldmat));
	}
}

static inline struct material_instance*
find_submit_material(lua_State *L, struct ecs_world *w, const component::render_args *ra, uint32_t rmidx) {
	auto mi = get_material(w->R, rmidx, ra->material_index);
	
	if (nullptr == mi)
		return nullptr;

	const auto prog = material_prog(L, mi);
	if (!BGFX_HANDLE_IS_VALID(prog))
		return nullptr;

	return mi;
}

static inline bool
find_submit_mesh(const component::render_object *ro, const component::indirect_object *io) {
	if (ro->vb_num == 0 || (io && io->draw_num == 0))
		return false;

	const uint16_t ibtype = BUFFER_TYPE(ro->ib_handle);
	if (ibtype != INVALID_BUFFER_TYPE && ro->ib_num == 0)
		return false;

	return true;
}

static inline void
draw_indirect_obj(lua_State *L, struct ecs_world *w, bgfx_view_id_t viewid,
	const component::render_object *ro, const component::indirect_object* io,
	const struct material_instance *mi, uint32_t material_idx, bgfx_program_handle_t prog,
	uint8_t discardflags, obj_transforms &trans){
	if (io->draw_num == 0){
		return ;
	}
	apply_material_instance(L, mi, w);
	mesh_submit(w, ro, viewid);

	const auto itb = bgfx_dynamic_vertex_buffer_handle_t{(uint16_t)io->itb_handle};
	assert(BGFX_HANDLE_IS_VALID(itb));
	w->bgfx->encoder_set_instance_data_from_dynamic_vertex_buffer(w->holder->encoder, itb, 0, io->draw_num);

	transform t = update_transform(w, ro, MATH_NULL, trans);
	w->bgfx->encoder_set_transform_cached(w->holder->encoder, t.tid, t.stride);

	const auto idb = bgfx_indirect_buffer_handle_t{(uint16_t)io->idb_handle};
	assert(BGFX_HANDLE_IS_VALID(idb));
	w->bgfx->encoder_submit_indirect(w->holder->encoder, viewid, prog, idb, 0, io->draw_num, ro->render_layer, discardflags);
}

static inline void
draw_obj(lua_State *L, struct ecs_world *w, bgfx_view_id_t viewid,
	const component::render_object *ro, 
	const struct material_instance *mi, uint32_t material_idx, bgfx_program_handle_t prog,
	const matrix_array *mats, uint8_t discardflags,
	obj_transforms &trans){

	apply_material_instance(L, mi, w);
	mesh_submit(w, ro, viewid);
	
	transform t;
	if (mats){
		for (int i=0; i<(int)mats->size()-1; ++i) {
			t = update_transform(w, ro, (*mats)[i], trans);
			w->bgfx->encoder_set_transform_cached(w->holder->encoder, t.tid, t.stride);
			w->bgfx->encoder_submit(w->holder->encoder, viewid, prog, ro->render_layer, BGFX_DISCARD_TRANSFORM);
		}
		t = update_transform(w, ro, mats->back(), trans);
	} else {
		t = update_transform(w, ro, MATH_NULL, trans);
	}

	w->bgfx->encoder_set_transform_cached(w->holder->encoder, t.tid, t.stride);
	w->bgfx->encoder_submit(w->holder->encoder, viewid, prog, ro->render_layer, discardflags);
}

using group_queues = std::array<matrix_array, MAX_VISIBLE_QUEUE>;
using group_collection = std::unordered_map<int, group_queues>;

static constexpr uint16_t MAX_SUBMIT_NUM = 4096;
struct submit_context {
	lua_State *L;
	struct ecs_world* w;
	const component::render_args* ra[MAX_VISIBLE_QUEUE];
	uint8_t ra_count;

	void clear() {
#ifdef RENDER_DEBUG
		L = nullptr;
		w = nullptr;
#endif //RENDER_DEBUG
		ra_count = 0;
	}
};

struct obj_submiter {
	struct submit_object {
		const component::render_object *ro;
		const struct material_instance* mi;
		bgfx_program_handle_t prog;

		const component::indirect_object *io;
	#ifdef RENDER_DEBUG
		component::eid eid;
	#endif //RENDER_DEBUG
	};

	void add(const component::render_object *ro, const component::indirect_object *io
#ifdef RENDER_DEBUG
	, component::eid eid
#endif //RENDER_DEBUG
	){
		if (!find_submit_mesh(ro, io))
			return ;

		//TODO
		// auto mi = find_submit_material(ctx->L, ctx->w, ctx->ra, ro, io);
		// if (!mi){
		// 	return ;
		// }

		assert(num < MAX_SUBMIT_NUM);
		objects[num++] = submit_object{
			ro, nullptr, UINT16_MAX, io
#ifdef RENDER_DEBUG
			, eid
#endif //RENDER_DEBUG
		};
	}

	//TODO
	void sort(){}

	void submit(obj_transforms &trans){
		
		for (uint8_t ii=0; ii<ctx->ra_count; ++ii){
			auto ra = ctx->ra[ii];
			for (uint16_t is=0; is<num; ++is){
				const submit_object& so = objects[is];
				if (obj_visible(ctx->w->Q, *so.ro, ra->queue_index)){
					auto mi = find_submit_material(ctx->L, ctx->w, ra, so.ro->rm_idx);
					if (mi){
					const auto prog = material_prog(ctx->L, mi);
						if (BGFX_HANDLE_IS_VALID(prog)){
							if (so.io){
								draw_indirect_obj(ctx->L, ctx->w, ra->viewid, so.ro, so.io, mi, ra->material_index, prog, BGFX_DISCARD_ALL, trans);
							} else {
								draw_obj(ctx->L, ctx->w, ra->viewid, so.ro, mi, ra->material_index, prog, nullptr, BGFX_DISCARD_ALL, trans);
							}
						}

					}
				}
			}
			//ctx->w->bgfx->encoder_discard(w->holder->encoder, BGFX_DISCARD_ALL);
		}

	}

	void clear(){
		ctx = nullptr;
		num = 0;
	}

	submit_context *ctx = nullptr;
	submit_object objects[MAX_SUBMIT_NUM];
	uint16_t num = 0;

	//TODO
	//uint16_t submit_queues[MAX_VISIBLE_QUEUE][MAX_SUBMIT_NUM];
};

struct hitch_submiter {
	struct submit_hitch{
		const component::render_object *ro;
		const struct material_instance* mi;
		bgfx_program_handle_t prog;

		const group_queues* g;
		const component::efk_object* eo;
	#ifdef RENDER_DEBUG
		component::eid eid;
	#endif //RENDER_DEBUG
	};

	void add(
		const component::render_object *ro,
		const component::efk_object *eo,
		const group_queues* g
#ifdef RENDER_DEBUG
	, component::eid eid
#endif //RENDER_DEBUG
	){
		if (ro && !find_submit_mesh(ro, nullptr)){
			return ;
		}

		assert(ro || eo);
		//TODO:
		//auto mi = find_submit_material();
		assert(num < MAX_SUBMIT_NUM);
		hitchs[num++] = submit_hitch{
			ro, nullptr, UINT16_MAX, g, eo
#ifdef RENDER_DEBUG
			, eid
#endif //RENDER_DEBUG
		};
	}

	//TODO:
	void sort(){}

	//
	void submit(obj_transforms &trans) {
		for (uint8_t ii=0; ii<ctx->ra_count; ++ii){
			auto ra = ctx->ra[ii];
			for (uint16_t ih=0; ih<num; ++ih){
				const submit_hitch& sh = hitchs[ih];
				
				const auto &mats = (*sh.g)[ra->queue_index];
				if (!mats.empty()){
					if (sh.ro && queue_check(ctx->w->Q, sh.ro->visible_idx, ra->queue_index)){
						auto mi = find_submit_material(ctx->L, ctx->w, ra, sh.ro->rm_idx);
						if (mi){
							const auto prog = material_prog(ctx->L, mi);
							if (BGFX_HANDLE_IS_VALID(prog)){
								draw_obj(ctx->L, ctx->w, ra->viewid, sh.ro, mi, ra->material_index, prog, &mats, BGFX_DISCARD_ALL, trans);
							}
						}
					}

					if (sh.eo && queue_check(ctx->w->Q, sh.eo->visible_idx, ra->queue_index)){
						submit_efk_obj(ctx->L, ctx->w, sh.eo, mats);
					}
				}
			}

			//ctx->w->bgfx->encoder_discard(w->holder->encoder, BGFX_DISCARD_ALL);
		}
	}

	void clear(){
		ctx = nullptr;
		num = 0;
	}

	submit_context *ctx = nullptr;
	submit_hitch hitchs[MAX_SUBMIT_NUM];
	uint16_t num = 0;

	//uint16_t submit_queues[MAX_VISIBLE_QUEUE][MAX_SUBMIT_NUM];
};

struct submit_cache{
	obj_transforms	transforms;
	group_collection	groups;

	submit_context		ctx;
	obj_submiter		obj;
	hitch_submiter		hitch;

#ifdef RENDER_DEBUG
	struct submit_stat{
		uint32_t hitch_submit;
		uint32_t simple_submit;
		uint32_t efk_hitch_submit;
		uint32_t hitch_count;
	};

	submit_stat stat;
#endif //RENDER_DEBUG

	void clear_groups(){
		for (auto &g : groups){
			for (std::vector<math_t> &q : g.second){
				q.clear();
			}
		}
	}

	void clear(){
		ctx.clear();
		transforms.clear();
		clear_groups();

		obj.clear();
		hitch.clear();

		obj.ctx = hitch.ctx = &ctx;

#ifdef RENDER_DEBUG
		memset(&stat, 0, sizeof(stat));
#endif //RENDER_DEBUG
	}
};

static inline void
find_render_args(struct ecs_world *w, submit_cache &cc) {
	for (auto& r : ecs::array<component::render_args>(w->ecs)) {
		cc.ctx.ra[cc.ctx.ra_count++] = &r;
	}
}

static inline void
build_hitch_info(struct ecs_world*w, submit_cache &cc){
	for (auto e : ecs::select<component::hitch_visible, component::hitch, component::scene>(w->ecs)) {
		const auto &h = e.get<component::hitch>();
		for (uint8_t ii=0; ii<cc.ctx.ra_count; ++ii){
			auto ra = cc.ctx.ra[ii];
			if (obj_visible(w->Q, h, ra->queue_index)){
				const auto &s = e.get<component::scene>();
				if (h.group != 0){
					cc.groups[h.group][ra->queue_index].emplace_back(s.worldmat);
					#ifdef RENDER_DEBUG
					++cc.stat.hitch_count;
					#endif //RENDER_DEBUG
				}
			}
		}
	}
}

static inline bool notdiscards(uint16_t viewid){
	return viewid == 2 || viewid == 3 || viewid == 4 || viewid == 5 || viewid == 12;
}

static inline void
render_hitch_submit(lua_State *L, ecs_world* w, submit_cache &cc){
	// draw object which hanging on hitch node
	ecs::clear_type<component::efk_hitch>(w->ecs);
	for (auto const& [groupid, g] : cc.groups) {
		int gids[] = {groupid};
		ecs::group_enable<component::hitch_tag>(w->ecs, gids);

		for (auto& e : ecs::select<component::hitch_tag>(w->ecs)) {
			const auto io = e.component<component::indirect_object>();
			if (!io){
				const auto ro = e.component<component::render_object>();
				const auto eo = e.component<component::efk_object>();
				if (ro || eo){
				#ifdef RENDER_DEBUG
					auto eid = e.component<component::eid>();
					cc.hitch.add(ro, eo, &g, eid);
				#else
					cc.hitch.add(ro, eo, &g);
				#endif //RENDER_DEBUG
				}
			}
		}
	}

	cc.hitch.submit(cc.transforms);
}

static inline void
render_submit(lua_State *L, struct ecs_world* w, submit_cache &cc){
	// draw simple objects
	for (auto& e : ecs::select<component::render_object_visible, component::render_object>(w->ecs)) {
		const component::indirect_object* io = e.component<component::indirect_object>();
		const auto& ro = e.get<component::render_object>();

	#ifdef RENDER_DEBUG
		auto eid = e.component<component::eid>();(void)eid;
		cc.obj.add(&ro, io, eid);
	#else
		cc.obj.add(&ro, io);
	#endif //RENDER_DEBUG
	}

	cc.obj.submit(cc.transforms);
}

static submit_cache cc;

static int
lrender_submit(lua_State *L) {
	auto w = getworld(L);
	cc.clear();
	cc.ctx.L = L;
	cc.ctx.w = w;

	find_render_args(w, cc);
	build_hitch_info(w, cc);
	render_submit(L, w, cc);
	render_hitch_submit(L, w, cc);
	
	return 0;
}

// static int
// lrender_preprocess(lua_State *L){
// 	auto w = getworld(L);
// 	cc.clear();

// 	find_render_args(w, cc);
// 	build_hitch_info(w, cc);
// 	return 0;
// }

// static int
// lrender_hitch_submit(lua_State *L){
// 	auto w = getworld(L);
// 	render_hitch_submit(L, w, cc);
// 	return 0;
// }

// static int
// lrender_postprocess(lua_State *L){
// 	return 0;
// }

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

static int
linit_system(lua_State *L){
	auto w = getworld(L);
	w->R = render_material_create();
	w->Q = queue_create();
	return 1;
}

static int
lexit(lua_State *L){
	auto w = getworld(L);
	render_material_release(w->R);
	w->R = nullptr;

	queue_destroy(w->Q);
	w->Q = nullptr;

	return 0;
}

static int
lsubmit_stat(lua_State *L){
	lua_createtable(L, 0, 4);
#ifdef RENDER_DEBUG
	lua_pushinteger(L, cc.stat.hitch_submit);
	lua_setfield(L, -2, "hitch_submit");

	lua_pushinteger(L, cc.stat.simple_submit);
	lua_setfield(L, -2, "simple_submit");

	lua_pushinteger(L, cc.stat.efk_hitch_submit);
	lua_setfield(L, -2, "efk_hitch_submit");

	lua_pushinteger(L, cc.stat.hitch_count);
	lua_setfield(L, -2, "hitch_count");
#endif //RENDER_DEBUG
	return 1;
}

extern "C" int
luaopen_render_stat(lua_State *L){
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "submit_stat",	lsubmit_stat},
		{ nullptr, 			nullptr},
	};
	luaL_newlibtable(L,l);
	luaL_setfuncs(L,l,0);
	return 1;
}

extern "C" int
luaopen_system_render(lua_State *L){
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init_system",		linit_system},
		{ "exit",				lexit},
		//{ "render_preprocess",	lrender_preprocess},
		{ "render_submit", 		lrender_submit},
		//{ "render_hitch_submit",lrender_hitch_submit},
		//{ "render_postprocess", lrender_postprocess},
		{ nullptr, 				nullptr },
	};
	luaL_newlibtable(L,l);
	lua_pushnil(L);
	luaL_setfuncs(L,l,1);
	return 1;
}