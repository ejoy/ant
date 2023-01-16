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
get_material(const ecs::render_object* ro, size_t qidx){
	return (struct material_instance*)(*(&ro->mat_mq + qidx));
}

static void
draw(lua_State *L, struct ecs_world *w, const ecs::render_object *ro, bgfx_view_id_t viewid, size_t queueidx, obj_transforms &trans){
	if (mesh_submit(w, ro)){
		auto t = update_transform(w, ro, trans);
		w->bgfx->encoder_set_transform_cached(w->holder->encoder, t.tid, t.stride);
		auto mi = get_material(ro, queueidx);
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

template <typename Name, typename TagCull, typename TagVisible>
struct render_queue {
	static constexpr inline const char* name = Name::name;
	using cull = TagCull;
	using visible = TagVisible;
};

template <typename ...Tags>
struct tag_array {
	static constexpr size_t N = sizeof...(Tags);
	template <size_t Is>
	using at = std::remove_cvref_t<decltype(std::get<Is>(std::tuple<Tags...>()))>;
};

#define ConstString(NAME) struct conststr_##NAME { static constexpr inline const char* name = #NAME; };
#define RengerQueue(NAME) render_queue<conststr_##NAME, ecs::NAME##_cull, ecs::NAME##_visible>

ConstString(main_queue)
ConstString(pre_depth_queue)
ConstString(pickup_queue)
ConstString(csm1_queue)
ConstString(csm2_queue)
ConstString(csm3_queue)
ConstString(csm4_queue)
ConstString(bake_lightmap_queue)
ConstString(postprocess_obj_queue)

using tag_queue = tag_array<
	RengerQueue(main_queue),
	RengerQueue(pre_depth_queue),
	RengerQueue(pickup_queue),
	RengerQueue(csm1_queue),
	RengerQueue(csm2_queue),
	RengerQueue(csm3_queue),
	RengerQueue(csm4_queue),
	RengerQueue(bake_lightmap_queue),
	RengerQueue(postprocess_obj_queue)
>;
static_assert(offsetof(ecs::render_object, mat_ppoq) - offsetof(ecs::render_object, mat_mq) == sizeof(int64_t) * (tag_queue::N-1), "Invalid material data size");

template <typename Entity>
void collect_render_objs(Entity& e, ecs_api::context& ecs, const matrix_array *mats, objarray &objs) {
	auto& ro = e.template get<ecs::render_object>();
#if defined(_MSC_VER) && defined(_DEBUG)
	auto id = e.sibling<ecs::eid>(ecs);
	objs.emplace_back(obj_data{ &ro, mats, id });
#else
	objs.emplace_back(obj_data{ &ro, mats });
#endif
}

template<typename SubClass>
struct collect_objects_base {
	static constexpr size_t N = tag_queue::N;
	using JumpTable = std::array<void(*)(ecs_api::context&, const matrix_array*, objarray &), N>;

	template <size_t ...Is>
	constexpr static void init_(JumpTable& jump, std::index_sequence<Is...>) {
		static_cast<void>(std::initializer_list<int>{(jump[Is] = SubClass::template run<Is>, 0)...});
	}
	constexpr static auto init() {
		JumpTable jump;
		init_(jump, std::make_index_sequence<N>());
		return jump;
	}
	void operator() (ecs_api::context& ecs, const matrix_array* mats, size_t i, objarray &objs) {
		constinit static auto jump = init();
		if (i >= N) {
			return;
		}
		jump[i](ecs, mats, objs);
	}
};

struct collect_objects : public collect_objects_base<collect_objects> {
	template <size_t Is>
	static void run(ecs_api::context& ecs, const matrix_array* mats, objarray &objs) {
		using namespace ecs_api::flags;
		for (auto& e : ecs.select<ecs::view_visible, typename tag_queue::at<Is>::visible, typename tag_queue::at<Is>::cull(absent), ecs::render_object>()){
			collect_render_objs(e, ecs, mats, objs);
		}
	}

};
collect_objects s_collect_objects;

struct collect_hitch_objects : public collect_objects_base<collect_hitch_objects> {
	template <size_t Is>
	static void run(ecs_api::context& ecs, const matrix_array* mats, objarray &objs) {
		using namespace ecs_api::flags;
		for (auto& e : ecs.select<ecs::hitch_tag, typename tag_queue::at<Is>::visible, ecs::render_object>()){
			collect_render_objs(e, ecs, mats, objs);
		}
	}
};
collect_hitch_objects s_collect_hitch_objects;

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

static int
lsubmit(lua_State *L) {
	auto w = getworld(L);
	ecs_api::context ecs {w->ecs};

	group_matrices groups;
	for (auto e : ecs.select<ecs::view_visible, ecs::hitch, ecs::scene>()){
		const auto &h = e.get<ecs::hitch>();
		const auto &s = e.get<ecs::scene>();
		if (h.group != 0){
			groups[h.group].push_back(s.worldmat);
		}
	}

	obj_transforms trans;

	for (auto a : ecs.select<ecs::render_args>()){
		const auto& ra = a.get<ecs::render_args>();
		if (ra.material_index > tag_queue::N) {
			luaL_error(L, "Invalid material_index in render_args:%d", ra.material_index);
		}

		objarray objs;
		s_collect_objects(ecs, nullptr, ra.material_index, objs);
		for (auto const& [groupid, mats] : groups) {
			int gids[] = {groupid};
			ecs.group_enable<ecs::hitch_tag>(gids);
			s_collect_hitch_objects(ecs, &mats, ra.material_index, objs);
		}

		std::sort(std::begin(objs), std::end(objs), [](const auto &lhs, const auto &rhs){
			return lhs.obj->render_layer < rhs.obj->render_layer;
		});
		draw_objs(L, w, ra, objs, trans);
	}
	return 0;
}

template <size_t Is = 0>
static size_t find_queue(const char* name, size_t def) {
	if constexpr (Is < tag_queue::N) {
		if (strcmp(tag_queue::at<Is>::name, name) == 0) {
			return Is;
		}
		return find_queue<Is+1>(name, def);
	}
	return def;
}

template<size_t Qidx = 0>
static const char* find_queue_name(size_t idx){
	if constexpr (Qidx < tag_queue::N) {
		return (Qidx != idx) ? find_queue_name<Qidx+1>(idx) : tag_queue::at<Qidx>::name;
	}

	return "";
}

static size_t to_queue_material_idx(lua_State *L, int idx) {
	if (lua_type(L, idx) == LUA_TSTRING) {
		auto name = lua_tostring(L, idx);
		return find_queue(name, 0);
	}
	return 0;
}

static int
ldraw(lua_State *L) {
	auto w = getworld(L);
	const cid_t draw_tagid = (cid_t)luaL_checkinteger(L, 1);
	const bgfx_view_id_t viewid = (bgfx_view_id_t)luaL_checkinteger(L, 2);
	obj_transforms trans;
	const size_t qm_idx = to_queue_material_idx(L, 3);
	for (int i=0; entity_iter(w->ecs, draw_tagid, i); ++i){
		const auto ro = (ecs::render_object*)entity_sibling(w->ecs, draw_tagid, i, ecs_api::component<ecs::render_object>::id);
		if (ro == nullptr)
			return luaL_error(L, "id:%d is not a render_object entity");
		
		draw(L, w, ro, viewid, qm_idx, trans);
	}
	return 0;
}

static int
lnull(lua_State *L){
	lua_pushlightuserdata(L, nullptr);
	return 1;
}

//TODO: queue index will failed when dynamic material is used
static int
lmaterial_index(lua_State *L) {
	auto queuename = luaL_checkstring(L, 1);
	auto idx = find_queue(queuename, -1);
	if (idx == -1) {
		return 0;
	}
	lua_pushinteger(L, idx);
	return 1;
}

extern "C" int
luaopen_render(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "submit", lsubmit},
		{ "draw",	ldraw},
		{ "material_index", lmaterial_index},
		{ "null",	lnull},
		{ nullptr, nullptr },
	};
	luaL_newlibtable(L,l);
	lua_pushnil(L);
	luaL_setfuncs(L,l,1);
	return 1;
}