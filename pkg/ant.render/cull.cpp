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
#include <algorithm>


using tags = std::vector<cid_t>;
using cull_infos = std::unordered_map<uint64_t, tags>;

template<typename Entity>
static inline void
enable_tags(Entity &e, const tags& t){
	for (auto id : t){
		e.enable_tag(id);
	}
}

template<typename Entity>
static inline void
distable_tags(Entity &e, tags t){
	for (auto id : t){
		e.disable_tag(id);
	}
}

static int
lcull(lua_State *L){
	auto w = getworld(L);

	cull_infos ci;
	for (auto e : ecs_api::select<ecs::cull_args>(w->ecs)){
		const auto& i = e.get<ecs::cull_args>();
		ci[i.frustum_planes.idx].push_back((cid_t)i.renderable_id);
	}

	if (ci.empty())
		return 0;

	for (auto e : ecs_api::select<ecs::view_visible, ecs::render_object, ecs::bounding>(w->ecs)){
		const auto &b = e.get<ecs::bounding>();
		for (const auto& kv : ci){
			if (!math_isnull(b.scene_aabb)){
				if (math3d_frustum_intersect_aabb(w->math3d->M, math_t{kv.first}, b.scene_aabb) < 0){
					distable_tags(e, kv.second);

					continue;
				}
			}

			enable_tags(e, kv.second);
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
