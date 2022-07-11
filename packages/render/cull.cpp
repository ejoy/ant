#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"

#include <memory>

extern "C"{
	#include "math3d.h"
	#include "math3dfunc.h"
}


typedef int64_t math3d_id;

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
	auto math3d = w->math3d->LS;

	const math3d_id vpid = math3d_mark_id(L, w->math3d, 3);
	int vpmat_type = LINEAR_TYPE_NONE;
	const float* vpmat = math3d_value(w->math3d, vpid, &vpmat_type);
	if (vpmat_type != LINEAR_TYPE_MAT){
		luaL_error(L, "Invalid math3d id, need matrix type:%d", vpmat_type);
	}

#define define_plane_array(_T, _N, _P) _T _N[6] = {_P[0], _P[1], _P[2], _P[3], _P[4], _P[5], };

	float planes[6][4];
	define_plane_array(float*, parr, planes);
	define_plane_array(const float*, cparr, planes);
	math3d_frustum_planes(w->math3d->LS, vpmat, parr, math3d_homogeneous_depth());
	for (auto e : ecs.select<ecs::view_visible, ecs::render_object, ecs::scene>()){
		auto s = e.get<ecs::scene>();
		int type;
		const float* aabb = math3d_value(w->math3d, s.scene_aabb, &type);
		if (type != LINEAR_TYPE_NULL){
			if (type != LINEAR_TYPE_MAT){
				return luaL_error(L, "Invalid scene_aabb, need matrix type:%d", type);
			}

			if (math3d_frustum_intersect_aabb(w->math3d->LS, cparr, aabb) < 0){
				for (int ii=0; ii<numtab; ++ii){
					ecs.enable_tag(e, s_cull_tabs[ii]);
				}
			} else {
				for (int ii=0; ii<numtab; ++ii){
					ecs.disable_tag(e, s_cull_tabs[ii]);
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
	luaL_newlib(L, l);
	return 1;
}
