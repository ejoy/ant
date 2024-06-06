#include <lua.hpp>
#include <bee/lua/udata.h>
#include "ozz.h"

static int BuildSkinningMatrices(lua_State *L) {
	auto& skinning_matrices = bee::lua::checkudata<ozzMatrixVector>(L, 1);
	auto& current_pose = bee::lua::checkudata<ozzMatrixVector>(L, 2);
	auto& inverse_bind_matrices = bee::lua::checkudata<ozzMatrixVector>(L, 3);
	if (skinning_matrices.size() < inverse_bind_matrices.size()) {
		return luaL_error(L, "invalid skinning matrices and inverse bind matrices, skinning matrices must larger than inverse bind matrices");
	}
	if (!lua_isnoneornil(L, 4)) {
		auto& jarray = bee::lua::checkudata<ozzUint16Verctor>(L, 4);
		assert(jarray.size() == inverse_bind_matrices.size());
		if (!lua_isnoneornil(L, 5)) {
			auto& worldmat = *(const ozz::math::Float4x4*)(lua_touserdata(L, 5));
			for (size_t ii = 0; ii < jarray.size(); ++ii){
				const auto m = current_pose[jarray[ii]] * inverse_bind_matrices[ii];
				skinning_matrices[ii] = worldmat * m;
			}
		} else {
			for (size_t ii = 0; ii < jarray.size(); ++ii){
				skinning_matrices[ii] = current_pose[jarray[ii]] * inverse_bind_matrices[ii];
			}
		}
	}
	else {
		assert(current_pose.size() == inverse_bind_matrices.size() && skinning_matrices.size() == current_pose.size());
		if (!lua_isnoneornil(L, 5)) {
			auto& worldmat = *(const ozz::math::Float4x4*)(lua_touserdata(L, 5));
			for (size_t ii = 0; ii < inverse_bind_matrices.size(); ++ii){
				const auto m = current_pose[ii] * inverse_bind_matrices[ii];
				skinning_matrices[ii] = worldmat * m;
			}
		} else {
			for (size_t ii = 0; ii < inverse_bind_matrices.size(); ++ii){
				skinning_matrices[ii] = current_pose[ii] * inverse_bind_matrices[ii];
			}
		}
	}
	return 0;
}

void init_skinning(lua_State *L) {
	luaL_Reg l[] = {
		{ "BuildSkinningMatrices", BuildSkinningMatrices },
		{ NULL, NULL },
	};
	luaL_setfuncs(L,l,0);
}
