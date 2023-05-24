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

#define MAX_CULL_ARRAY 64
#define MAX_CULL_CID 1024

static inline int
insert_cull_array(struct cull_array cull_a[], int n_cull, cid_t cid_a[], int n_cid, uint64_t mid, cid_t cid) {
	int i;
	int offset = 0;
	for (i=0;i<n_cull;i++) {
		offset += cull_a[i].n;
		if (cull_a[i].mid == mid) {
			++cull_a[i].n;
			memmove(cid_a + offset + 1, cid_a + offset, sizeof(cid_t) * (n_cid - offset));
			cid_a[offset] = cid;
			return n_cull;
		}
	}
	assert(n_cull < MAX_CULL_ARRAY);
	assert(offset == n_cid);
	cull_a[n_cull].mid = mid;
	cull_a[n_cull].n = 1;
	cid_a[n_cid] = cid;
	return n_cull + 1;
}

static int
lcull(lua_State *L) {
	struct cull_array a[MAX_CULL_ARRAY];
	int a_n = 0;
	cid_t cid[MAX_CULL_CID];
	int c_n = 0;

	auto w = getworld(L);

	for (auto e : ecs_api::select<ecs::cull_args>(w->ecs)){
		const auto& i = e.get<ecs::cull_args>();
		const auto id = (cid_t)i.renderable_id;
		assert(c_n < MAX_CULL_CID);
		a_n = insert_cull_array(a, a_n, cid, c_n++, i.frustum_planes.idx, id);
		entity_clear_type(w->ecs, id);
	}

	if (a_n == 0)
		return 0;

	static ecs_api::cached<ecs::view_visible, ecs::bounding> cached_select(w->ecs);
	for (auto e : ecs_api::select(cached_select)) {
		const auto &b = e.get<ecs::bounding>();
		int i,j,offset = 0;
		for (i = 0; i < a_n; i++) {
			if (math_isnull(b.scene_aabb) || 
				(math3d_frustum_intersect_aabb(w->math3d->M, math_t{a[i].mid}, b.scene_aabb) >= 0)) {
				for (j = 0; j < a[i].n; j++) {
					e.enable_tag(cid[offset+j]);
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
		{ "cull", lcull },
		{ NULL, NULL },
	};
	luaL_newlibtable(L,l);
	lua_pushnil(L);
	luaL_setfuncs(L,l,1);
	return 1;
}
