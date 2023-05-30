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

#define MAX_CULL_ARRAY	16
#define MAX_CULL_MASK	64

static inline int
insert_cull_array(struct cull_array cull_a[], int n_cull, uint64_t cullmasks[], int n_mask, uint64_t mid, uint64_t cullmask) {
	int i;
	int offset = 0;
	for (i=0;i<n_cull;i++) {
		offset += cull_a[i].n;
		if (cull_a[i].mid == mid) {
			++cull_a[i].n;
			memmove(cullmasks + offset + 1, cullmasks + offset, sizeof(uint64_t) * (n_mask - offset));
			cullmasks[offset] = cullmask;
			return n_cull;
		}
	}
	assert(n_cull < MAX_CULL_ARRAY);
	assert(offset == n_mask);
	cull_a[n_cull].mid = mid;
	cull_a[n_cull].n = 1;
	return n_cull + 1;
}

using cull_cached_select = ecs_api::cached<ecs::view_visible, ecs::bounding, ecs::render_object>;

static int
linit(lua_State *L) {
	auto w = getworld(L);
	w->create_member<cull_cached_select>(w->ecs);
	return 0;
}

static int
lexit(lua_State *L) {
	auto w = getworld(L);
	w->destroy_member<cull_cached_select>();
	return 0;
}

static int
lcull(lua_State *L) {
	struct cull_array a[MAX_CULL_ARRAY];
	int a_n = 0;
	uint64_t cullmasks[MAX_CULL_MASK];
	int c_n = 0;

	auto w = getworld(L);

	for (auto e : ecs_api::select<ecs::cull_args>(w->ecs)){
		const auto& i = e.get<ecs::cull_args>();
		assert(c_n < MAX_CULL_MASK);
		a_n = insert_cull_array(a, a_n, cullmasks, c_n++, i.frustum_planes.idx, i.cull_mask);
	}

	if (a_n == 0)
		return 0;

	for (auto e : ecs_api::select(w->get_member<cull_cached_select>())) {
		const auto &b = e.get<ecs::bounding>();

		if (math_isnull(b.scene_aabb))
			continue;

		auto &ro = e.get<ecs::render_object>();

		int i,j,offset = 0;
		for (i = 0; i < a_n; i++) {
			const bool isculled = math3d_frustum_intersect_aabb(w->math3d->M, math_t{a[i].mid}, b.scene_aabb) < 0;
			if (isculled){
				for (j = 0; j < a[i].n; j++) {
					ro.cull_masks |= cullmasks[offset+j];
				}
			} else {
				for (j = 0; j < a[i].n; j++) {
					ro.cull_masks &= ~cullmasks[offset+j];
				}
			}
			offset += a[i].n;
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
