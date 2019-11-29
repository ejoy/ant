#include "hierarchy.h"
#include "ozz_mesh/mesh.h"

#include "meshbase/meshbase.h"

extern "C" {
#define LUA_LIB
#include "lua.h"
#include "lauxlib.h"
}

#include <ozz/animation/runtime/animation.h>
#include <ozz/animation/runtime/sampling_job.h>
#include <ozz/animation/runtime/local_to_model_job.h>
#include <ozz/animation/runtime/blending_job.h>
#include <ozz/animation/runtime/skeleton.h>

#include <ozz/geometry/runtime/skinning_job.h>
#include <ozz/base/platform.h>

#include <ozz/base/maths/soa_transform.h>
#include <ozz/base/maths/soa_float4x4.h>

#include <ozz/base/memory/allocator.h>
#include <ozz/base/io/stream.h>
#include <ozz/base/io/archive.h>
#include <ozz/base/containers/vector.h>
#include <ozz/base/maths/math_ex.h>

// glm
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

// stl
#include <string>
#include <cstring>
#include <algorithm>

struct animation_node {
	ozz::animation::Animation		*ani;	
};

struct sampling_node {
	ozz::animation::SamplingCache *		cache;	
};

struct ozzmesh {
	ozz::sample::Mesh* mesh;
	ozz::Range<ozz::math::Float4x4>	skinning_matrices;

	uint8_t * dynamic_buffer;
	uint8_t * static_buffer;

	Bounding bounding;
};

template<typename T>
static ozz::Range<T>
create_range(size_t count) {
	auto beg = ozz::memory::default_allocator()->Allocate(sizeof(T) * count, OZZ_ALIGN_OF(T));
	return ozz::Range<T>(reinterpret_cast<T*>(beg), count);
}

static size_t 
dynamic_vertex_elem_stride(ozzmesh *om) {
	auto mesh = om->mesh;
	if (mesh->parts.empty()) {
		return 0;
	}

	const auto &part = mesh->parts.back();
	assert(!part.positions.empty());

	size_t num_elem = ozz::sample::Mesh::Part::kPositionsCpnts;
	if (!part.normals.empty())
		num_elem += ozz::sample::Mesh::Part::kNormalsCpnts;

	if (!part.tangents.empty())
		num_elem += ozz::sample::Mesh::Part::kTangentsCpnts;

	return sizeof(float) * num_elem;		
}

static size_t 
static_vertex_elem_stride(ozzmesh *om) {
	auto mesh = om->mesh;
	if (mesh->parts.empty())
		return 0;

	const auto &part = mesh->parts.back();
	assert(!part.positions.empty());

	size_t stride = 0;
	if (!part.colors.empty())
		stride += ozz::sample::Mesh::Part::kColorsCpnts * sizeof(uint8_t);

	if (!part.uvs.empty())
		stride += ozz::sample::Mesh::Part::kUVsCpnts * sizeof(float);

	return stride;
}

static int
llayout_ozzmesh(lua_State *L) {
	int numarg = lua_gettop(L);
	if (numarg < 2) {
		luaL_error(L, "need 1: ozzmesh, 2: type(dynamic/static) two argument");
		return 0;
	}
	luaL_checktype(L, 1, LUA_TUSERDATA);
	ozzmesh *om = (ozzmesh*)lua_touserdata(L, 1);
	luaL_checktype(L, 2, LUA_TSTRING);
	const char* type = lua_tostring(L, 2);
	
	const char *deflayout = "_30NIf";
	auto mesh = om->mesh;

	auto &part = mesh->parts.back();

	std::string layout;
	if (strcmp(type, "dynamic") == 0) {
		std::string pos(deflayout);
		pos[0] = 'p';
		layout = pos;

		if (!part.normals.empty()) {
			std::string normal(deflayout);
			normal[0] = 'n';
			normal[1] = '0' + ozz::sample::Mesh::Part::kNormalsCpnts;
			layout += "|" + normal;
		}

		if (!part.tangents.empty()) {
			std::string tangent(deflayout);
			tangent[0] = 'T';
			tangent[1] = '0' + ozz::sample::Mesh::Part::kTangentsCpnts;
			layout += "|" + tangent;
		}

	} else if (strcmp(type, "static") == 0) {
		if (!part.colors.empty()) {
			std::string color(deflayout);
			color[0] = 'c';
			color[1] = '0' + ozz::sample::Mesh::Part::kColorsCpnts;
			color[3] = 'n';
			color[5] = 'u';
			layout = color;		
		}

		if (!part.uvs.empty()) {
			std::string uv(deflayout);
			uv[0] = 't';
			uv[1] = '0' + ozz::sample::Mesh::Part::kUVsCpnts;
			if (layout.empty())
				layout = uv;
			else
				layout += "|" + uv;
		}
	} else {
		luaL_error(L, "not support type : %s", type);
	}

	lua_pushstring(L, layout.c_str());
	return 1;
}

static int
lskinning(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	ozzmesh *om = (ozzmesh*)lua_touserdata(L, 1);

	luaL_checktype(L, 2, LUA_TUSERDATA);
	bindpose_result *ani = (bindpose_result*)lua_touserdata(L, 2);
	assert(om->mesh);

	auto &mesh = *(om->mesh);

	for (size_t ii = 0; ii < mesh.joint_remaps.size(); ++ii) {		
		om->skinning_matrices[ii] =
			ani->pose[mesh.joint_remaps[ii]] * mesh.inverse_bind_poses[ii];
	}

	// offset
	const size_t positions_offset = 0;
	const size_t normals_offset = sizeof(float) * ozz::sample::Mesh::Part::kPositionsCpnts;
	const size_t tangents_offset = normals_offset + sizeof(float) * (ozz::sample::Mesh::Part::kNormalsCpnts);

	// stride
	const size_t positions_stride = sizeof(float) * (ozz::sample::Mesh::Part::kPositionsCpnts 
													+ ozz::sample::Mesh::Part::kNormalsCpnts 
													+ ozz::sample::Mesh::Part::kTangentsCpnts);
	const size_t normals_stride = positions_stride;
	const size_t tangents_stride = positions_stride;

	size_t processed_vertex_count = 0;
	for (const auto& part : mesh.parts) {
		const size_t part_vertex_count = part.vertex_count();
		if (part_vertex_count == 0)
			continue;

		// Fills the job.
		ozz::geometry::SkinningJob skinning_job;
		skinning_job.vertex_count = static_cast<int>(part_vertex_count);
		const int part_influences_count = part.influences_count();

		// Clamps joints influence count according to the option.
		skinning_job.influences_count = part_influences_count;

		// Setup skinning matrices, that came from the animation stage before being
		// multiplied by inverse model-space bind-pose.
		skinning_job.joint_matrices = om->skinning_matrices;

		// Setup joint's indices.
		skinning_job.joint_indices = make_range(part.joint_indices);
		skinning_job.joint_indices_stride =
			sizeof(uint16_t) * part_influences_count;

		// Setup joint's weights.
		if (part_influences_count > 1) {
			skinning_job.joint_weights = make_range(part.joint_weights);
			skinning_job.joint_weights_stride =
				sizeof(float) * (part_influences_count - 1);
		}

		// Setup input positions, coming from the loaded mesh.
		skinning_job.in_positions = make_range(part.positions);
		skinning_job.in_positions_stride =
			sizeof(float) * ozz::sample::Mesh::Part::kPositionsCpnts;

		// Setup output positions, coming from the rendering output mesh buffers.
		// We need to offset the buffer every loop.
		skinning_job.out_positions.begin = reinterpret_cast<float*>(
			ozz::PointerStride(om->dynamic_buffer, positions_offset + processed_vertex_count *
				positions_stride));
		skinning_job.out_positions.end = ozz::PointerStride(
			skinning_job.out_positions.begin, part_vertex_count * positions_stride);
		skinning_job.out_positions_stride = positions_stride;

		// Setup normals if input are provided.
		float* out_normal_begin = reinterpret_cast<float*>(ozz::PointerStride(
			om->dynamic_buffer, normals_offset + processed_vertex_count * normals_stride));
		const float* out_normal_end = ozz::PointerStride(
			out_normal_begin, part_vertex_count * normals_stride);

		if (part.normals.size() / ozz::sample::Mesh::Part::kNormalsCpnts ==
			part_vertex_count) {
			// Setup input normals, coming from the loaded mesh.
			skinning_job.in_normals = make_range(part.normals);
			skinning_job.in_normals_stride =
				sizeof(float) * ozz::sample::Mesh::Part::kNormalsCpnts;

			// Setup output normals, coming from the rendering output mesh buffers.
			// We need to offset the buffer every loop.
			skinning_job.out_normals.begin = out_normal_begin;
			skinning_job.out_normals.end = out_normal_end;
			skinning_job.out_normals_stride = normals_stride;
		} else {
			// Fills output with default normals.
			for (float* normal = out_normal_begin; normal < out_normal_end;
				normal = ozz::PointerStride(normal, normals_stride)) {
				normal[0] = 0.f;
				normal[1] = 1.f;
				normal[2] = 0.f;
			}
		}

		// Setup tangents if input are provided.
		float* out_tangent_begin = reinterpret_cast<float*>(ozz::PointerStride(
			om->dynamic_buffer, tangents_offset + processed_vertex_count * tangents_stride));
		const float* out_tangent_end = ozz::PointerStride(
			out_tangent_begin, part_vertex_count * tangents_stride);

		if (part.tangents.size() / ozz::sample::Mesh::Part::kTangentsCpnts ==
			part_vertex_count) {
			// Setup input tangents, coming from the loaded mesh.
			skinning_job.in_tangents = make_range(part.tangents);
			skinning_job.in_tangents_stride =
				sizeof(float) * ozz::sample::Mesh::Part::kTangentsCpnts;

			// Setup output tangents, coming from the rendering output mesh buffers.
			// We need to offset the buffer every loop.
			skinning_job.out_tangents.begin = out_tangent_begin;
			skinning_job.out_tangents.end = out_tangent_end;
			skinning_job.out_tangents_stride = tangents_stride;
		} else {
			// Fills output with default tangents.
			for (float* tangent = out_tangent_begin; tangent < out_tangent_end;
				tangent = ozz::PointerStride(tangent, tangents_stride)) {
				tangent[0] = 1.f;
				tangent[1] = 0.f;
				tangent[2] = 0.f;
			}
		}

		// Execute the job, which should succeed unless a parameter is invalid.
		if (!skinning_job.Run()) {
			return false;
		}

		processed_vertex_count += part_vertex_count;
	}

	return 0;
}

static inline ozz::animation::Skeleton*
get_ske(lua_State *L, int idx = 1) {
	luaL_checktype(L, idx, LUA_TUSERDATA);
	hierarchy_build_data *builddata = (hierarchy_build_data *)lua_touserdata(L, 1);

	auto ske = builddata->skeleton;
	if (ske == nullptr) {
		luaL_error(L, "skeleton is not init!");
	}

	return ske;
}

static inline animation_node*
get_aninode(lua_State *L, int idx = 2) {
	luaL_checktype(L, idx, LUA_TUSERDATA);
	animation_node * aninode = (animation_node*)lua_touserdata(L, 2);
	if (aninode->ani == nullptr) {
		luaL_error(L, "animation is not init!");
		return 0;
	}

	return aninode;
}

static inline sampling_node*
get_samplingnode(lua_State *L, ozz::animation::Skeleton* ske, int idx = 3) {
	luaL_checktype(L, idx, LUA_TUSERDATA);
	sampling_node * samplingnode = (sampling_node*)lua_touserdata(L, idx);
	return samplingnode;
}

static inline float
get_ratio(lua_State*L, int idx = 4) {
	luaL_checktype(L, idx, LUA_TNUMBER);
	return (float)lua_tonumber(L, idx);
}

static inline bindpose_result*
get_aniresult(lua_State *L, ozz::animation::Skeleton* ske, int idx) {
	luaL_checktype(L, idx, LUA_TUSERDATA);
	bindpose_result* result = (bindpose_result*) lua_touserdata(L, idx);
	if (result->pose.size() != (size_t)ske->num_joints()) {
		luaL_error(L, "animation result joint count:%d, is not equal to skeleton joint number: %d", result->pose.size(), ske->num_joints());
	}

	return result;
}

static inline bind_pose*
get_bindpose(lua_State *L, int idx) {
	luaL_checktype(L, idx, LUA_TUSERDATA);
	return (bind_pose*)lua_touserdata(L, idx);
}

struct sample_info {
	animation_node *aninode;
	sampling_node *sampling;
	float ratio;
	float weight;
};


static inline bool
do_sample(const ozz::animation::Skeleton *ske, 
			const sample_info &si, bind_pose &result) {
	ozz::animation::SamplingJob job;
	job.animation = si.aninode->ani;
	job.cache = si.sampling->cache;
	job.ratio = si.ratio;
	job.output = ozz::make_range(result.pose);

	return job.Run();
}

bool
do_ltm(ozz::animation::Skeleton *ske, 
	const ozz::Vector<ozz::math::SoaTransform>::Std &intermediateResult, 
	ozz::Vector<ozz::math::Float4x4>::Std &joints,
	const ozz::math::Float4x4 *root = nullptr,
	int from = ozz::animation::Skeleton::kNoParent,
	int to = ozz::animation::Skeleton::kMaxJoints) {
	ozz::animation::LocalToModelJob ltmjob;
	ltmjob.root = root;
	ltmjob.input = ozz::make_range(intermediateResult);
	ltmjob.skeleton = ske;
	ltmjob.output = ozz::make_range(joints);

	return ltmjob.Run();
}

struct blendlayers {
	ozz::Vector<ozz::animation::BlendingJob::Layer>::Std layers;
	ozz::Vector<bind_pose>::Std results;
};

static inline void
load_sample_info(lua_State *L, int index, sample_info &si) {	
	luaL_checktype(L, index, LUA_TTABLE);

	lua_getfield(L, index, "handle");
	si.aninode = (animation_node*)lua_touserdata(L, -1);
	lua_pop(L, 1);

	lua_getfield(L, index, "sampling_cache");
	si.sampling = (sampling_node*)lua_touserdata(L, -1);
	lua_pop(L, 1);

	lua_getfield(L, index, "ratio");
	si.ratio = (float)lua_tonumber(L, -1);
	lua_pop(L, 1);

	lua_getfield(L, -1, "weight");
	si.weight = (float)lua_tonumber(L, -1);
	lua_pop(L, 1);
}

static inline bool
sample_animation(const ozz::animation::Skeleton *ske, const sample_info &si, bind_pose *bindpose) {
	bindpose->pose.resize(ske->num_soa_joints());
	//assert(ske->joint_parents()[0] == ozz::animation::Skeleton::kNoParent);
	return do_sample(ske, si, *bindpose);
}

static int
lsample_animation(lua_State *L) {
	auto ske = get_ske(L, 1);	
	sample_info si;
	load_sample_info(L, 2, si);
	bind_pose *bindpose = (bind_pose*)lua_touserdata(L, 3);

	if (!sample_animation(ske, si, bindpose)) {
		luaL_error(L, "sampling animation failed");
	}
	return 0;
}

static inline int
find_root_index(const ozz::animation::Skeleton *ske) {
	const auto jointcount = ske->num_joints();
	const auto &parents = ske->joint_parents();
	for (auto ii = 0; ii < jointcount; ++ii) {
		auto &parent = parents[ii];
		if (parent == ozz::animation::Skeleton::kNoParent)
			return ii;
	}

	return -1;
}

static inline void
fetch_float4x4(const ozz::math::SoaTransform &trans, int subidx, ozz::math::Float4x4 &f4x4) {
	const ozz::math::SoaFloat4x4 local_soa_matrices = ozz::math::SoaFloat4x4::FromAffine(
		trans.translation, trans.rotation, trans.scale);

	// Converts to aos matrices.
	ozz::math::Float4x4 local_aos_matrices[4];
	ozz::math::Transpose16x16(&local_soa_matrices.cols[0].x,
		local_aos_matrices->cols);

	f4x4 = local_aos_matrices[subidx];
}

template<typename PoseRanage>
static inline ozz::math::Float4x4
extract_joint_matrix(const PoseRanage &poses, int jointidx) {
	assert(jointidx >= 0);
	
	const auto soa_rootidx = jointidx / 4;
	const auto aos_subidx = jointidx % 4;

	const auto &pose = poses[soa_rootidx];
	ozz::math::Float4x4 mat;
	fetch_float4x4(pose, aos_subidx, mat);
	return mat;
}

static inline void
fix_root_translation(ozz::animation::Skeleton *ske, soa_poses &pose){
	auto rootidx = find_root_index(ske);
	const auto soa_rootidx = rootidx / 4;
	const auto aos_subidx = rootidx % 4;

	auto& trans = pose[soa_rootidx];
	auto newtrans = ozz::math::simd_float4::Load1(0.0f);
	trans.translation.x = ozz::math::SetI(trans.translation.x, newtrans, 0);
	trans.translation.y = ozz::math::SetI(trans.translation.y, newtrans, 0);
	trans.translation.z = ozz::math::SetI(trans.translation.z, newtrans, 0);
}

static inline bool
transform_bindpose(ozz::animation::Skeleton *ske, 
	soa_poses &pose,
	result_poses& resultpose,
	bool fixroot){
	ozz::math::Float4x4 rootmat;
	if (fixroot){
		fix_root_translation(ske, pose);
	} else {
		rootmat = ozz::math::Float4x4::identity();
	}
	
	return do_ltm(ske, pose, resultpose);
}

static int
ltransform_to_bindpose_result(lua_State *L) {
	auto ske = get_ske(L, 1);
	auto bindpose = get_bindpose(L, 2);
	auto result = get_aniresult(L, ske, 3);
	auto fixroot = lua_isnoneornil(L, 4) ? false : lua_toboolean(L, 4);

	if (!transform_bindpose(ske, bindpose->pose, result->pose, fixroot)) {
		luaL_error(L, "transform bind pose is failed!");
	}
	return 0;
}

static void
create_blend_layers(lua_State *L, int index, 
	const ozz::animation::Skeleton *ske, 
	blendlayers &bl) {
	const int numani = (int)lua_rawlen(L, index);

	bl.layers.resize(numani);
	bl.results.resize(numani);

	auto& layers = bl.layers;
	auto& results = bl.results;

	for (int ii = 0; ii < numani; ++ii) {
		lua_geti(L, index, ii + 1);

		sample_info si;
		load_sample_info(L, -1, si);

		auto &result = results[ii];		
		if (!sample_animation(ske, si, &result)) {
			luaL_error(L, "sampling animation failed!");
		}

		layers[ii].weight = si.weight;
		layers[ii].transform = ozz::make_range(result.pose);

		lua_pop(L, 1);
	}
}

static inline bool
do_blend(const ozz::animation::Skeleton *ske, 
	const ozz::Vector<ozz::animation::BlendingJob::Layer>::Std &layers, 
	const char* blendtype, 
	float threshold, 
	bind_pose *finalpose) {
	ozz::animation::BlendingJob blendjob;
	blendjob.bind_pose = ske->joint_bind_poses();

	auto jobrange = ozz::make_range(layers);
	if (strcmp(blendtype, "blend") == 0) {
		blendjob.layers = jobrange;
	} else if (strcmp(blendtype, "additive") == 0) {
		blendjob.additive_layers = jobrange;
	} else {
		return false;
	}

	blendjob.threshold = threshold;
	blendjob.output = ozz::make_range(finalpose->pose);

	return blendjob.Run();
}

static int
lblend_bind_poses(lua_State *L) {
	const auto ske = get_ske(L, 1);
	luaL_checktype(L, 2, LUA_TTABLE);

	int numposes = (int)lua_rawlen(L, 2);
	blendlayers bl;
	bl.layers.resize(numposes);
	bl.results.resize(numposes);

	for (int ii = 0; ii < numposes; ++ii) {
		lua_geti(L, 2, ii+1);
		{
			luaL_checktype(L, -1, LUA_TTABLE);
			lua_getfield(L, -1, "pose");
			auto pose = (bind_pose*)lua_touserdata(L, -1);
			lua_pop(L, 1);

			lua_getfield(L, -1, "weight");
			const float weight = (float)lua_tonumber(L, -1);
			lua_pop(L, 1);

			bl.layers[ii].weight = weight;
			bl.layers[ii].transform = ozz::make_range(pose->pose);
		}
		lua_pop(L, 1);
	}

	const char* blendtype = lua_tostring(L, 3);
	bind_pose *finalpose = (bind_pose*)lua_touserdata(L, 4);
	const float threshold = (float)luaL_optnumber(L, 5, 0.1f);

	finalpose->pose.resize(ske->num_soa_joints());
	do_blend(ske, bl.layers, blendtype, threshold, finalpose);

	return 0;
}

static bool
blend_animations(lua_State *L, 
	int ani_index,
	const char* blendtype, const ozz::animation::Skeleton *ske, float threshold, 
	bind_pose *bindpose) {

	blendlayers bl;
	create_blend_layers(L, ani_index, ske, bl);

	if (bl.layers.empty()) {
		return true;
	}

	if (bl.layers.size() > 1) {
		bindpose->pose.resize(ske->num_soa_joints());
		do_blend(ske, bl.layers, blendtype, threshold, bindpose);
	} else {
		auto &result = bl.results.back();
		bindpose->pose = std::move(result.pose);
	}
	
	return true;
}

static int
lblend_animations(lua_State *L) {
	auto ske = get_ske(L, 1);	
	const char* blendtype = lua_tostring(L, 3);
	auto bindpose = get_bindpose(L, 4);

	const float threshold = (float)luaL_optnumber(L, 5, 0.1f);

	blend_animations(L, 2, blendtype, ske, threshold, bindpose);

	assert(bindpose->pose.size() == ske->joint_bind_poses().count());

	return 0;
}

static int
lmotion(lua_State *L) {
	auto ske = get_ske(L, 1);	
	luaL_checktype(L, 3, LUA_TSTRING);
	const char* blendtype = lua_tostring(L, 3);
	auto aniresult = get_aniresult(L, ske, 4);

	const float threshold = (float)luaL_optnumber(L, 5, 0.1f);
	const bool fixroot = lua_isnoneornil(L, 6) ? false : lua_toboolean(L, 6);
 
	bind_pose bindpose;
	blend_animations(L, 2, blendtype, ske, threshold, &bindpose);

	if (!transform_bindpose(ske, bindpose.pose, aniresult->pose, fixroot)){
		return luaL_error(L, "doing blend result to ltm job failed!");
	}

	return 0;
}

static inline void
create_joint_table(lua_State *L, const ozz::math::Float4x4 &joint) {
	lua_createtable(L, 16, 0);
	for (auto icol = 0; icol < 4; ++icol) {
		for (auto ii = 0; ii < 4; ++ii) {
			const float* col = (const float*)(&(joint.cols[icol]));
			lua_pushnumber(L, col[ii]);
			lua_seti(L, -2, icol * 4 + ii + 1);
		}
	}
}

static int
lbp_result_joint(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	bindpose_result * result = (bindpose_result*)lua_touserdata(L, 1);

	luaL_checktype(L, 2, LUA_TNUMBER);
	const size_t idx = (size_t)lua_tointeger(L, 2);
	const auto joint_count = result->pose.size();

	if (idx >= joint_count) {
		luaL_error(L, "invalid index:%d, joints count:%d", idx, joint_count);
	}

	auto &joint = result->pose[idx];
	if (lua_isnoneornil(L, 3)){
		auto p = &(joint.cols[0]);
		lua_pushlightuserdata(L, (void*)p);
		return 1;
	}

	joint = *(ozz::math::Float4x4*)lua_touserdata(L, 3);
	return 0;
}

static int
lbp_result_joints(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	const bindpose_result * result = (bindpose_result*)lua_touserdata(L, 1);

	auto jointcount = result->pose.size();
	lua_createtable(L, (int)jointcount, 0);

	for (size_t ii = 0; ii < jointcount; ++ii) {
		create_joint_table(L, result->pose[ii]);
		lua_seti(L, -2, ii + 1);
	}
	return 1;
}

static int
lbp_result_count(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	const bindpose_result * result = (bindpose_result*)lua_touserdata(L, 1);

	lua_pushinteger(L, result->pose.size());
	return 1;
}

static int
lbp_result_transform(lua_State *L){
	luaL_checktype(L, 1, LUA_TUSERDATA);
	bindpose_result * result = (bindpose_result*)lua_touserdata(L, 1);

	auto mat = (const ozz::math::Float4x4*)lua_touserdata(L, 2);
	auto except_root = lua_isnoneornil(L, 3) ? false : lua_toboolean(L, 3);

	for (int ii = (except_root ? 1 : 0); ii < result->pose.size(); ++ii){
		result->pose[ii] = *mat * result->pose[ii];
	}
	
	return 0;
}

static int
ldel_sampling(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	sampling_node *sampling = (sampling_node *)lua_touserdata(L, 1);
	ozz::memory::default_allocator()->Delete(sampling->cache);	

	return 0;
}

static int
lnew_sampling_cache(lua_State *L) {
	luaL_checktype(L, 1, LUA_TNUMBER);
	const int numjoints = (int)lua_tointeger(L, 1);

	if (numjoints <= 0) {
		luaL_error(L, "joints number should be > 0");
		return 0;
	}

	sampling_node* samplingnode = (sampling_node*)lua_newuserdatauv(L, sizeof(sampling_node), 0);
	luaL_getmetatable(L, "SAMPLING_NODE");
	lua_setmetatable(L, -2);

	samplingnode->cache = ozz::memory::default_allocator()->New<ozz::animation::SamplingCache>(numjoints);
	return 1;
}

static int
ldel_bpresult(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	bindpose_result *result = (bindpose_result *)lua_touserdata(L, 1);	
	result->pose.~vector();
	return 0;
}

static int
lnew_bpresult(lua_State *L) {
	luaL_checktype(L, 1, LUA_TNUMBER);
	const size_t numjoints = (size_t)lua_tointeger(L, 1);

	if (numjoints <= 0) {
		luaL_error(L, "joints number should be > 0");
		return 0;
	}

	bindpose_result *result = (bindpose_result*)lua_newuserdatauv(L, sizeof(bindpose_result), 0);
	luaL_getmetatable(L, "BPRESULT_NODE");
	lua_setmetatable(L, -2);	
	new(&result->pose)ozz::Vector<ozz::math::Float4x4>::Std(numjoints);

	return 1;
}

static int
ldel_animation(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);

	animation_node *node = (animation_node*)lua_touserdata(L, 1);
	ozz::memory::default_allocator()->Delete(node->ani);	
	
	return 0;
}

static int
lnew_animation(lua_State *L) {
	luaL_checktype(L, 1, LUA_TSTRING);
	const char * path = lua_tostring(L, 1);

	animation_node *node = (animation_node*)lua_newuserdatauv(L, sizeof(animation_node), 0);
	luaL_getmetatable(L, "ANIMATION_NODE");
	lua_setmetatable(L, -2);
	
	node->ani = ozz::memory::default_allocator()->New<ozz::animation::Animation>();

	ozz::io::File file(path, "rb");
	if (!file.opened()) {
		luaL_error(L, "file could not open : %s", path);
	}

	ozz::io::IArchive archive(&file);
	if (!archive.TestTag<ozz::animation::Animation>()) {		
		luaL_error(L, "file is not ozz::animation, file : %s", path);
	}
	archive >> *(node->ani);
	return 1;
}

static int
lduration_animation(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	animation_node *node = (animation_node*)lua_touserdata(L, 1);
	lua_pushnumber(L, node->ani->duration());
	return 1;
}

static int
ldel_ozzmesh(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);

	ozzmesh *om = (ozzmesh*)lua_touserdata(L, 1);

	if (om->mesh) {
		ozz::memory::default_allocator()->Delete(om->mesh);
		ozz::memory::default_allocator()->Deallocate(om->skinning_matrices.begin);
	}

	if (om->dynamic_buffer) {
		delete[] om->dynamic_buffer;
		om->dynamic_buffer = nullptr;
	}

	if (om->static_buffer) {
		delete[] om->static_buffer;
		om->static_buffer = nullptr;
	}

	return 0;
}

static void 
create_buffer(ozzmesh *om) {
	const auto num_vertices = om->mesh->vertex_count();

	auto &aabb = om->bounding.aabb;
	const size_t dynamic_stride = dynamic_vertex_elem_stride(om);
	if (dynamic_stride != 0) {
		om->dynamic_buffer = new uint8_t[dynamic_stride * num_vertices];
		auto *db = om->dynamic_buffer;
		const size_t posstep = ozz::sample::Mesh::Part::kPositionsCpnts * sizeof(float);
		const size_t normalstep = ozz::sample::Mesh::Part::kNormalsCpnts * sizeof(float);
		const size_t tangentstep = ozz::sample::Mesh::Part::kTangentsCpnts * sizeof(float);

		if (!om->mesh->parts.empty()) {
			auto v = (const glm::vec3*)(&om->mesh->parts.front().positions[0]);
			assert(!aabb.IsValid());
			aabb.Init(v, 3);
		}

		for (const auto &part : om->mesh->parts) {
			assert(0 != part.vertex_count());			
			for (auto iv = 0; iv < part.vertex_count(); ++iv) {
				auto posptr = &(part.positions[iv * ozz::sample::Mesh::Part::kPositionsCpnts]);				
				aabb.Append(*(glm::vec3*)(posptr));
				memcpy(db, posptr, posstep);
				db += posstep;

				if (!part.normals.empty()) {
					memcpy(db, &(part.normals[iv * ozz::sample::Mesh::Part::kNormalsCpnts]), normalstep);
					db += normalstep;
				}

				if (!part.tangents.empty()) {
					memcpy(db, &(part.tangents[iv * ozz::sample::Mesh::Part::kTangentsCpnts]), tangentstep);
					db += tangentstep;
				}
			}
		}
	} else {
		om->dynamic_buffer = nullptr;
	}	
	
	om->bounding.sphere.Init(aabb);
	om->bounding.obb.Init(aabb);

	const size_t static_stride = static_vertex_elem_stride(om);
	if (static_stride != 0) {
		om->static_buffer = new uint8_t[static_stride * num_vertices];
		uint8_t *sb = om->static_buffer;
		const size_t colorstep = ozz::sample::Mesh::Part::kColorsCpnts * sizeof(uint8_t);
		const size_t uvstep = ozz::sample::Mesh::Part::kUVsCpnts * sizeof(float);
		for (const auto &part : om->mesh->parts) {
			for (auto iv = 0; iv < part.vertex_count(); ++iv) {
				if (!part.colors.empty()) {
					memcpy(sb, &(part.colors[iv * size_t(ozz::sample::Mesh::Part::kColorsCpnts)]), colorstep);
					sb += colorstep;
				}
				if (!part.uvs.empty()) {
					memcpy(sb, &(part.uvs[iv * size_t(ozz::sample::Mesh::Part::kUVsCpnts)]), uvstep);
					sb += uvstep;
				}
			}
		}
	} else {
		om->static_buffer = nullptr;
	}
}

namespace ozz {
	namespace sample {
		static bool LoadMesh(const char* _filename, ozz::sample::Mesh* _mesh) {
			assert(_filename && _mesh);
			//ozz::log::Out() << "Loading mesh archive: " << _filename << "." << std::endl;
			ozz::io::File file(_filename, "rb");
			if (!file.opened()) {
				//ozz::log::Err() << "Failed to open mesh file " << _filename << "."
				//	<< std::endl;
				return false;
			}
			ozz::io::IArchive archive(&file);
			if (!archive.TestTag<ozz::sample::Mesh>()) {
				//ozz::log::Err() << "Failed to load mesh instance from file " << _filename
				//	<< "." << std::endl;
				return false;
			}

			// Once the tag is validated, reading cannot fail.
			archive >> *_mesh;

			return true;
		}
	}
}

static int
lnew_ozzmesh(lua_State *L) {
	luaL_checktype(L, 1, LUA_TSTRING);

	const char* filename = lua_tostring(L, 1);

	ozzmesh *om = (ozzmesh*)lua_newuserdatauv(L, sizeof(ozzmesh), 0);
	luaL_getmetatable(L, "OZZMESH");
	lua_setmetatable(L, -2);

	om->bounding = Bounding();

	om->mesh = ozz::memory::default_allocator()->New<ozz::sample::Mesh>();
	ozz::sample::LoadMesh(filename, om->mesh);

	if (!om->mesh->inverse_bind_poses.empty()) {
		om->skinning_matrices = create_range<ozz::math::Float4x4>(om->mesh->inverse_bind_poses.size());
	} else {
		om->skinning_matrices = ozz::Range<ozz::math::Float4x4>();
	}

	create_buffer(om);
	return 1;
}

static int
lnum_vertices(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	ozzmesh *om = (ozzmesh*)lua_touserdata(L, 1);
	lua_pushinteger(L, om->mesh->vertex_count());
	
	return 1;
}

static int
lnum_indices(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	ozzmesh *om = (ozzmesh*)lua_touserdata(L, 1);
	lua_pushinteger(L, om->mesh->triangle_index_count());
	return 1;
}

static int 
lbuffer_ozzmesh(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	ozzmesh *om = (ozzmesh*)lua_touserdata(L, 1);

	luaL_checktype(L, 2, LUA_TSTRING);
	const char* type = lua_tostring(L, 2);

	size_t vertex_stride = 0;
	uint8_t * buffer = nullptr;
	if (strcmp(type, "dynamic") == 0) {
		buffer = om->dynamic_buffer;
		vertex_stride = dynamic_vertex_elem_stride(om);
	} else if (strcmp(type, "static") == 0) {
		buffer = om->static_buffer;
		vertex_stride = static_vertex_elem_stride(om);
	} else {
		luaL_error(L, "not support type : %s", type);
	}
	
	lua_pushlightuserdata(L, buffer);
	lua_pushinteger(L, lua_Integer(vertex_stride * om->mesh->vertex_count()));
	return 2;
}

static int
lbounding_ozzmesh(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	auto om = (ozzmesh*)lua_touserdata(L, 1);

	auto push_vec = [L](auto name, auto num, auto obj) {
		lua_createtable(L, num, 0);
		for (auto ii = 0; ii < num; ++ii) {
			lua_pushnumber(L, obj[ii]);
			lua_seti(L, -2, ii + 1);
		}
		lua_setfield(L, -2, name);
	};
	
	lua_createtable(L, 0, 3);

	// aabb
	lua_createtable(L, 0, 2);
	push_vec("min", 3, om->bounding.aabb.min);
	push_vec("max", 3, om->bounding.aabb.max);
	lua_setfield(L, -2, "aabb");

	// sphere
	lua_createtable(L, 0, 2);

	push_vec("center", 3, om->bounding.sphere.center);
	lua_pushnumber(L, om->bounding.sphere.radius);
	lua_setfield(L, -2, "radius");

	lua_setfield(L, -2, "sphere");

	//obb
	push_vec("obb", 16, (const float*)(&om->bounding.obb.m));

	return 1;
}

static int
lindexbuffer_ozzmesh(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	ozzmesh *om = (ozzmesh*)lua_touserdata(L, 1);

	auto mesh = om->mesh;

	lua_pushlightuserdata(L, ozz::array_begin(mesh->triangle_indices));
	const size_t sizeInBytes = mesh->triangle_index_count() * sizeof(uint16_t);
	lua_pushinteger(L, lua_Integer(sizeInBytes));
	lua_pushinteger(L, sizeof(uint16_t));

	return 3;
}

static void 
register_animation_mt(lua_State *L) {
	luaL_newmetatable(L, "ANIMATION_NODE");
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");	// ANIMATION_NODE.__index = ANIMATION_NODE

	luaL_Reg l[] = {		
		{"duration", lduration_animation},		
		{"__gc", ldel_animation},
		{nullptr, nullptr},
	};

	luaL_setfuncs(L, l, 0);
}

static void
register_sampling_mt(lua_State *L) {
	luaL_newmetatable(L, "SAMPLING_NODE");
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_Reg l[] = {
		{"__gc", ldel_sampling},
		{nullptr, nullptr},
	};

	luaL_setfuncs(L, l, 0);
}

static void
register_bpresult_mt(lua_State *L) {
	luaL_newmetatable(L, "BPRESULT_NODE");
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_Reg l[] = {
		{"joint", lbp_result_joint},
		{"joints", lbp_result_joints},
		{"count", lbp_result_count},
		{"transform", lbp_result_transform},
		{"__gc", ldel_bpresult},
		{nullptr, nullptr},
	};

	luaL_setfuncs(L, l, 0);
}

static void
register_ozzmesh_mt(lua_State *L) {
	luaL_newmetatable(L, "OZZMESH");
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_Reg l[] = {		
		{"buffer", lbuffer_ozzmesh},
		{"num_vertices", lnum_vertices},
		{"num_indices", lnum_indices},
		{"index_buffer", lindexbuffer_ozzmesh},
		{"layout", llayout_ozzmesh},
		{"bounding", lbounding_ozzmesh},
		{"__gc", ldel_ozzmesh},
		{nullptr, nullptr},
	};

	luaL_setfuncs(L, l, 0);
}

static int
ldel_bind_pose(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	bind_pose *pose = (bind_pose*)lua_touserdata(L, 1);
	pose->pose.~vector();
	return 0;
}

static int
lnew_bind_pose(lua_State *L) {
	auto bp = (bind_pose*)lua_newuserdatauv(L, sizeof(bind_pose), 0);
	luaL_getmetatable(L, "OZZBINGPOSE");
	lua_setmetatable(L, -2);

	new(&bp->pose)ozz::Vector<ozz::math::SoaTransform>::Std();	
	return 1;
}

static void
register_bind_pose_mt(lua_State *L) {
	luaL_newmetatable(L, "OZZBINGPOSE");
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_Reg l[] = {
		{"__gc", ldel_bind_pose},
		{nullptr, nullptr},
	};

	luaL_setfuncs(L, l, 0);
}

extern "C" {
LUAMOD_API int
luaopen_hierarchy_animation(lua_State *L) {
	register_animation_mt(L);
	register_sampling_mt(L);
	register_ozzmesh_mt(L);
	register_bpresult_mt(L);
	register_bind_pose_mt(L);

	luaL_Reg l[] = {		
		{ "skinning", lskinning},
		{ "motion", lmotion},
		{ "blend_animations", lblend_animations},
		{ "blend_bind_poses", lblend_bind_poses},
		{ "sample_animation", lsample_animation},
		{ "transform", ltransform_to_bindpose_result},
		{ "new_ani", lnew_animation},
		{ "new_ozzmesh", lnew_ozzmesh},
		{ "new_sampling_cache", lnew_sampling_cache},
		{ "new_bind_pose_result", lnew_bpresult,},
		{ "new_bind_pose", lnew_bind_pose},
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

}