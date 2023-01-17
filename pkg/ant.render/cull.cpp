#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"

extern "C"{
	#include "math3d.h"
	#include "math3dfunc.h"
}

#include <memory>
#include <unordered_map>
#include <vector>

using cull_infos = std::unordered_map<uint64_t, std::vector<cid_t>>;

static int
lcull(lua_State *L){
	auto w = getworld(L);

	cull_infos ci;
	for (auto e : ecs_api::select<ecs::cull_args>(w->ecs)){
		const auto& i = e.get<ecs::cull_args>();
		ci[i.frustum_planes.idx].push_back((cid_t)i.cull_id);
	}

	if (ci.empty())
		return 0;

	for (auto e : ecs_api::select<ecs::view_visible, ecs::render_object, ecs::bounding>(w->ecs)){
		const auto &b = e.get<ecs::bounding>();
		if (math_isnull(b.scene_aabb))
			continue;

		for (const auto& kv : ci){
			if (math3d_frustum_intersect_aabb(w->math3d->M, math_t{kv.first}, b.scene_aabb) < 0){
				for (auto id : kv.second){
					e.enable_tag(id);
				}
			} else {
				for (auto id : kv.second){
					e.disable_tag(id);
				}
			}
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
