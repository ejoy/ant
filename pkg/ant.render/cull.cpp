#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"

extern "C"{
	#include "math3d.h"
	#include "math3dfunc.h"
}

#include <cassert>
#include <cstring>
#include <memory>
#include <unordered_map>
#include <vector>
#include <algorithm>


using tags = std::vector<cid_t>;
using cull_infos = std::unordered_map<uint64_t, tags>;

struct cull_array {
	uint64_t mid;
	int n;
};

struct cull_cached: public ecs_api::cached<ecs::view_visible, ecs::bounding, ecs::render_object> {
	cull_cached(struct ecs_context* ctx)
		: ecs_api::cached<ecs::view_visible, ecs::bounding, ecs::render_object>(ctx) {}
};

static int
linit(lua_State *L) {
	auto w = getworld(L);
	w->cull_cached = new struct cull_cached(w->ecs);
	return 0;
}

static int
lexit(lua_State *L) {
	auto w = getworld(L);
	delete w->cull_cached;
	return 0;
}

static int
lcull(lua_State *L) {
	auto w = getworld(L);
	constexpr uint8_t MAX_QUEUE_COUNT = 64;

	uint8_t c0 = 0;
	struct cullinfo{
		math_t		mid;
		uint64_t	masks;
	};
	uint8_t c = 0;
	struct cullinfo ci[MAX_QUEUE_COUNT];

	auto find_cull = [ci, c](math_t mid){
		for (uint8_t ii=0; ii<c;++ii){
			if (ci->mid.idx == mid.idx)
				return ii;
		}
		return MAX_QUEUE_COUNT;
	};

	for (auto e : ecs_api::select<ecs::cull_args>(w->ecs)){
		const auto& i = e.get<ecs::cull_args>();

		uint8_t which = find_cull(i.frustum_planes);
		if (MAX_QUEUE_COUNT == which){
			assert(c < MAX_QUEUE_COUNT);
			which = c;
			ci[c++] = {i.frustum_planes, 0};
		}
		ci[which].masks |= i.cull_mask;
	}

	if (0 == c)
		return 0;

	for (auto e : ecs_api::select(*w->cull_cached)) {
		const auto &b = e.get<ecs::bounding>();

		if (math_isnull(b.scene_aabb))
			continue;

		auto &ro = e.get<ecs::render_object>();
		for (uint8_t ii=0; ii<c; ++ii){
			
			const bool isculled = math3d_frustum_intersect_aabb(w->math3d->M, ci[ii].mid, b.scene_aabb) < 0;
			if (isculled){
				ro.cull_masks |= ci[ii].masks;
			} else {
				ro.cull_masks &= ~ci[ii].masks;
			}
		}
	}

	return 0;
}

extern "C" int
luaopen_system_cull(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "init", linit },
		{ "exit", lexit },
		{ "cull", lcull },
		{ NULL, NULL },
	};
	luaL_newlibtable(L,l);
	lua_pushnil(L);
	luaL_setfuncs(L,l,1);
	return 1;
}
