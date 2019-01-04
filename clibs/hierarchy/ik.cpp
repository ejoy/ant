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


static int
ldo_ik(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	hierarchy_build_data *builddata = (hierarchy_build_data *)lua_touserdata(L, 1);
	auto ske = builddata->skeleton;
	if (ske == nullptr) {
		luaL_error(L, "skeleton data must init!");
	}

	luaL_checktype(L, 2, LUA_TTABLE);


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
	}
}