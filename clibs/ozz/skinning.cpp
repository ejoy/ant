#include <lua.hpp>
#include <binding/binding.h>
#include "ozz.h"

#include <ozz/geometry/runtime/skinning_job.h>

template <typename DataType>
struct vertex_data {
	struct data_stride {
		typedef DataType Type;
		DataType* data = nullptr;
		uint32_t offset = 0;
		uint32_t stride = 0;
	};

	data_stride positions;
	data_stride normals;
	data_stride tangents;
};

struct in_vertex_data : public vertex_data<const void> {
	data_stride joint_weights;
	data_stride joint_indices;
};

typedef vertex_data<void> out_vertex_data;

template <typename DataStride>
static void
read_data_stride(lua_State *L, const char* name, int index, DataStride &ds){
	const int type = lua_getfield(L, index, name);
	if (type != LUA_TNIL)
	{
		lua_geti(L, -1, 1);
		const int type = lua_type(L, -1);
		switch (type){
		case LUA_TSTRING: ds.data = (typename DataStride::Type*)lua_tostring(L, -1); break;
		case LUA_TLIGHTUSERDATA:
		case LUA_TUSERDATA: ds.data = (typename DataStride::Type*)lua_touserdata(L, -1); break;
		default:
			luaL_error(L, "not support data type in data stride, only string and userdata is support, type:%d", type);
			return;
		}
		lua_pop(L, 1);

		lua_geti(L, -1, 2);
		ds.offset = (uint32_t)lua_tointeger(L, -1) - 1;
		lua_pop(L, 1);

		lua_geti(L, -1, 3);
		ds.stride = (uint32_t)lua_tointeger(L, -1);
		lua_pop(L, 1);
	}
	lua_pop(L, 1);
}

template<typename DataType>
static void
read_vertex_data(lua_State* L, int index, vertex_data<DataType>& vd) {
	read_data_stride(L, "POSITION", index, vd.positions);
	read_data_stride(L, "NORMAL", index, vd.normals);
	read_data_stride(L, "TANGENT", index, vd.tangents);
}

static void
read_in_vertex_data(lua_State *L, int index, in_vertex_data &vd){
	read_vertex_data(L, index, vd);
	read_data_stride(L, "WEIGHT", index, vd.joint_weights);
	read_data_stride(L, "INDICES", index, vd.joint_indices);
}

template<typename T, typename DataT>
static void
fill_skinning_job_field(uint32_t num_vertices, const DataT &d, ozz::span<T> &r, size_t &stride) {
	const uint8_t* begin_data = (const uint8_t*)d.data + d.offset;
	r = ozz::span<T>((T*)(begin_data), (T*)(begin_data + d.stride * num_vertices));
	stride = d.stride;
}

static void
build_skinning_matrices(ozz::vector<ozz::math::Float4x4>* skinning_matrices,
	const ozz::vector<ozz::math::Float4x4>* current_pose,
	const ozz::vector<ozz::math::Float4x4>* inverse_bind_matrices,
	const ozzJointRemap *jarray,
	const ozz::math::Float4x4 *worldmat){
	if (jarray){
		assert(jarray->joints.size() == inverse_bind_matrices->size());
		if (worldmat){
			for (size_t ii = 0; ii < jarray->joints.size(); ++ii){
				const auto m = (*current_pose)[jarray->joints[ii]] * (*inverse_bind_matrices)[ii];
				(*skinning_matrices)[ii] = (*worldmat) * m;
			}
		} else {
			for (size_t ii = 0; ii < jarray->joints.size(); ++ii){
				(*skinning_matrices)[ii] = (*current_pose)[jarray->joints[ii]] * (*inverse_bind_matrices)[ii];
			}
		}

	} else {
		assert(current_pose->size() == inverse_bind_matrices->size() && skinning_matrices->size() == current_pose->size());
		if (worldmat){
			for (size_t ii = 0; ii < inverse_bind_matrices->size(); ++ii){
				const auto m = (*current_pose)[ii] * (*inverse_bind_matrices)[ii];
				(*skinning_matrices)[ii] = (*worldmat) * m;
			}
		} else {
			for (size_t ii = 0; ii < inverse_bind_matrices->size(); ++ii){
				(*skinning_matrices)[ii] = (*current_pose)[ii] * (*inverse_bind_matrices)[ii];
			}
		}
	}
}

static int
lbuild_skinning_matrices(lua_State *L) {
	auto& skinning_matrices = bee::lua::checkudata<ozzBindpose>(L, 1);
	auto& current_bind_pose = bee::lua::checkudata<ozzPoseResult>(L, 2);
	auto& inverse_bind_matrices = bee::lua::checkudata<ozzBindpose>(L, 3);
	const ozzJointRemap* jarray = nullptr;
	if (!lua_isnoneornil(L, 4)) {
		auto& jm = bee::lua::checkudata<ozzJointRemap>(L, 4);
		jarray = &jm;
	}
	if (skinning_matrices.size() < inverse_bind_matrices.size()){
		return luaL_error(L, "invalid skinning matrices and inverse bind matrices, skinning matrices must larger than inverse bind matrices");
	}
	auto worldmat = lua_isnoneornil(L, 5) ? nullptr : (const ozz::math::Float4x4*)(lua_touserdata(L, 5));
	build_skinning_matrices(&skinning_matrices, &current_bind_pose, &inverse_bind_matrices, jarray, worldmat);
	return 0;
}

static int
lmesh_skinning(lua_State *L){
	auto& skinning_matrices = bee::lua::checkudata<ozzPoseResult>(L, 1);

	luaL_checktype(L, 2, LUA_TTABLE);
	in_vertex_data vd;
	read_in_vertex_data(L, 2, vd);

	luaL_checktype(L, 3, LUA_TTABLE);
	out_vertex_data ovd;
	read_vertex_data(L, 3, ovd);

	const uint32_t num_vertices = (uint32_t)luaL_checkinteger(L, 4);
	const uint32_t influences_count = (uint32_t)luaL_optinteger(L, 5, 4);

	ozz::geometry::SkinningJob skinning_job;
	skinning_job.vertex_count = num_vertices;
	skinning_job.influences_count = influences_count;
	skinning_job.joint_matrices = ozz::make_span(skinning_matrices);
	
	assert(vd.positions.data && "skinning system must provide 'position' attribute");

	fill_skinning_job_field(num_vertices, vd.positions, skinning_job.in_positions, skinning_job.in_positions_stride);
	fill_skinning_job_field(num_vertices, ovd.positions, skinning_job.out_positions, skinning_job.out_positions_stride);

	if (vd.normals.data) {
		fill_skinning_job_field(num_vertices, vd.normals, skinning_job.in_normals, skinning_job.in_normals_stride);
	}

	if (ovd.normals.data) {
		fill_skinning_job_field(num_vertices, ovd.normals, skinning_job.out_normals, skinning_job.out_normals_stride);
	}
	
	if (vd.tangents.data) {
		fill_skinning_job_field(num_vertices, vd.tangents, skinning_job.in_tangents, skinning_job.in_tangents_stride);
	}

	if (ovd.tangents.data) {
		fill_skinning_job_field(num_vertices, ovd.tangents, skinning_job.out_tangents, skinning_job.out_tangents_stride);
	}

	if (influences_count > 1) {
		assert(vd.joint_weights.data && "joint weight data is not valid!");
		fill_skinning_job_field(num_vertices, vd.joint_weights, skinning_job.joint_weights, skinning_job.joint_weights_stride);
	}
		
	assert(vd.joint_indices.data && "skinning job must provide 'indices' attribute");
	fill_skinning_job_field(num_vertices, vd.joint_indices, skinning_job.joint_indices, skinning_job.joint_indices_stride);

	if (!skinning_job.Run()) {
		luaL_error(L, "running skinning failed!");
	}

	return 0;
}

void init_skinning(lua_State *L) {
	luaL_Reg l[] = {
		{ "mesh_skinning",				lmesh_skinning},
		{ "build_skinning_matrices",	lbuild_skinning_matrices},
		{ NULL, NULL },
	};
	luaL_setfuncs(L,l,0);
}
