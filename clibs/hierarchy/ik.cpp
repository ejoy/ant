#include "hierarchy.h"
#include "ozz_mesh/mesh.h"

extern "C" {
#define LUA_LIB
#include "lua.h"
#include "lauxlib.h"
}

#include <ozz/animation/runtime/animation.h>
#include <ozz/animation/runtime/sampling_job.h>
#include <ozz/animation/runtime/local_to_model_job.h>
#include <ozz/animation/runtime/skeleton.h>

static ozz::math::Float4x4
to_matrix(lua_State *L, int idx) {
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	const float* m = (const float*)lua_touserdata(L, idx);
	ozz::math::Float4x4 sf;
	float* p = reinterpret_cast<float*>(&sf);
	for (int ii = 0; ii < 16; ++ii) {
		*p++ = m[ii];
	}
	return sf;
}

static int
ldo_ik(lua_State *L) {	
	ozz::math::Float4x4 rootMat = to_matrix(L, 1);
	luaL_checktype(L, 2, LUA_TUSERDATA);
	hierarchy_build_data *builddata = (hierarchy_build_data *)lua_touserdata(L, 1);
	auto ske = builddata->skeleton;
	if (ske == nullptr) {
		luaL_error(L, "skeleton data must init!");
	}

	luaL_checktype(L, 3, LUA_TTABLE);

	auto invRoot = ozz::math::Invert(rootMat);



	return 0;
}

extern "C" {
	LUAMOD_API int
	luaopen_hierarchy_ik(lua_State *L) {
		luaL_Reg l[] = {
			{ "do_ik", ldo_ik},
			{nullptr, nullptr},
		};

		luaL_newlib(L, l);
		return 1;
	}
}