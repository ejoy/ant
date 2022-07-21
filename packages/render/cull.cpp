#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"

#include <memory>

extern "C"{
	#include "math3d.h"
	#include "math3dfunc.h"
}

#define MATH3D(_FUNC, ...) world->math3d->_FUNC(world->math3d->LS, ...)
static int
lcull(lua_State *L){
	static uint16_t s_cull_tabs[16];
	const int numtab = (int)lua_rawlen(L, 2);
	if (numtab == 0){
		return 0;
	}

	if (numtab > sizeof(s_cull_tabs)/sizeof(s_cull_tabs[0])){
		return luaL_error(L, "Too many cull tabs");
	}

	for (int i=0; i<numtab; ++i){
		lua_geti(L, 2, i+1);
		s_cull_tabs[i] = (uint16_t)lua_tointeger(L, -1);
		lua_pop(L, 1);
	}

	auto w = getworld(L, 1);
	ecs_api::context ecs {w->ecs};

	const auto vpid = math3d_from_lua(L, w->math3d, 3, MATH_TYPE_MAT);
	const auto planes = math3d_frustum_planes(w->math3d->MC, vpid, math3d_homogeneous_depth());
	for (auto e : ecs.select<ecs::view_visible, ecs::render_object, ecs::scene>()){
		auto& s = e.get<ecs::scene>();
		const math_t aabb = {(uint64_t)s.scene_aabb};
		if (math_isnull(aabb))
			continue;

		if (math3d_frustum_intersect_aabb(w->math3d->MC, planes, aabb) < 0){
			for (int ii=0; ii<numtab; ++ii){
				e.enable_tag(ecs, s_cull_tabs[ii]);
			}
		} else {
			for (int ii=0; ii<numtab; ++ii){
				e.disable_tag(ecs, s_cull_tabs[ii]);
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
	luaL_newlib(L, l);
	return 1;
}
