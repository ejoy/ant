#include "hierarchy.h"

extern "C" {
#define LUA_LIB
#include "lua.h"
#include "lauxlib.h"
}

#include <ozz/animation/runtime/skeleton.h>
#include <ozz/animation/runtime/animation.h>
#include <ozz/animation/runtime/sampling_job.h>
#include <ozz/animation/runtime/local_to_model_job.h>
#include <ozz/animation/runtime/skeleton.h>

#include <ozz/animation/runtime/ik_two_bone_job.h>
#include <ozz/animation/runtime/ik_aim_job.h>

#include <ozz/base/maths/simd_math.h>
#include <ozz/base/maths/simd_quaternion.h>
#include <ozz/base/maths/soa_transform.h>

#include <ozz/base/containers/vector.h>

#include <string>

static ozz::math::Float4x4
to_matrix(lua_State *L, int idx) {
	ozz::math::Float4x4 sf;
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	const float* m = (const float*)lua_touserdata(L, idx);	
	float* p = reinterpret_cast<float*>(&sf);
	for (int ii = 0; ii < 16; ++ii) {
		*p++ = m[ii];
	}

	return sf;
}

bool
do_ltm(const ozz::animation::Skeleton *ske,
	const ozz::Vector<ozz::math::SoaTransform>::Std &intermediateResult,
	ozz::Vector<ozz::math::Float4x4>::Std &joints,
	const ozz::math::Float4x4 *root = nullptr,
	int from = ozz::animation::Skeleton::kNoParent,
	int to = ozz::animation::Skeleton::kMaxJoints);

#ifdef _DEBUG
#define verfiy(_c, _check)	assert((_c) == _check)
#else
#define verfiy(_c, _check)	(_c)
#endif // _DEBUG

static void
prepare_job(lua_State *L, int idx, 
	const ozz::Range<ozz::math::Float4x4> &models, 
	ik_data &ikdata) {
	luaL_checktype(L, idx, LUA_TTABLE);

	verfiy(lua_getfield(L, idx, "type"), LUA_TLIGHTUSERDATA);
	ikdata.type = lua_tostring(L, -1);
	lua_pop(L, 1);

	auto get_vec = [L](int idx, auto name, auto *result) {
		if (LUA_TNIL != lua_getfield(L, idx, name)){
			auto p = (const float*)lua_touserdata(L, -1);
			for (int ii = 0; ii < 4; ++ii) {
				*result++ = p[ii];
			}

			lua_pop(L, 1);
		}
	};

	// define in model space
	get_vec(idx, "target",		(float*)(&ikdata.target));
	get_vec(idx, "pole_vector", (float*)(&ikdata.pole_vector));

	// define in local space
	get_vec(idx, "mid_axis",	(float*)(&ikdata.mid_axis));

	auto get_number = [L](int idx, auto name) {
		verfiy(lua_getfield(L, idx, name), LUA_TNUMBER);
		const float value = (float)lua_tonumber(L, -1);
		lua_pop(L, 1);

		return value;
	};
	
	ikdata.weight = get_number(idx, "weight");
	ikdata.twist_angle = get_number(idx, "twist_angle");

	lua_getfield(L, idx, "joints");
	luaL_checktype(L, -1, LUA_TTABLE);{
		const auto len = lua_rawlen(L, -1);
		if (len <= 0 || 3 >len){
			luaL_error(L, "ik joints data must be in (0, 3], %d", len);
		}

		for (int ii = 0; ii < len; ++ii){
			lua_geti(L, -1, ii+1);
			ikdata.joints[ii] = (uint16_t)lua_tointeger(L, -1);
			lua_pop(L, 1);
		}
	}
	lua_pop(L, 1);

	if (ikdata.type == "twobone"){
		ikdata.soften = get_number(idx, "soften");
	}else if(ikdata.type == "aim"){
		get_vec(idx, "forward", (float*)(&ikdata.forward));
		get_vec(idx, "offset", (float*)(&ikdata.offset));
	}else{
		luaL_error(L, "not support type:%s", ikdata.type.c_str());
	}
	
}

static inline void 
mul_quaternion(size_t jointidx, const ozz::math::SimdQuaternion& quat,
	ozz::Vector<ozz::math::SoaTransform>::Std& transforms) {	

	ozz::math::SoaTransform& soa_transform_ref = transforms[jointidx / 4];
	ozz::math::SimdQuaternion aos_quats[4];
	ozz::math::Transpose4x4(&soa_transform_ref.rotation.x, &aos_quats->xyzw);

	ozz::math::SimdQuaternion& aos_joint_quat_ref = aos_quats[jointidx & 3];
	aos_joint_quat_ref = aos_joint_quat_ref * quat;

	ozz::math::Transpose4x4(&aos_quats->xyzw, &soa_transform_ref.rotation.x);
}

auto get_ske(lua_State *L, int index = 1){
	luaL_checktype(L, 1, LUA_TUSERDATA);
	hierarchy_build_data *builddata = (hierarchy_build_data *)lua_touserdata(L, 1);
	auto ske = builddata->skeleton;
	if (ske == nullptr) {
		luaL_error(L, "skeleton data must init!");
		return (ozz::animation::Skeleton*)nullptr;
	}

	return ske;
}

bool
do_ik(const ozz::animation::Skeleton *ske,
	const ik_data &ikdata,
	bind_pose_soa &bp, 
	bind_pose &result) {
	auto get_joint = [&result](int jointidx) {
		if (jointidx < 0 || jointidx > result.pose.size()){
			return (ozz::math::Float4x4*)nullptr;
		}

		return &result.pose[jointidx];
	};

	if (ikdata.type == "twobone"){
		ozz::animation::IKTwoBoneJob twobone_ikjob;

		twobone_ikjob.start_joint	= get_joint(ikdata.joints[0]);
		twobone_ikjob.mid_joint		= get_joint(ikdata.joints[1]);
		twobone_ikjob.end_joint		= get_joint(ikdata.joints[2]);

		twobone_ikjob.soften = ikdata.soften;
		twobone_ikjob.twist_angle = ikdata.twist_angle;
		twobone_ikjob.weight = ikdata.weight;

		ozz::math::SimdQuaternion start_correction, mid_correction;
		twobone_ikjob.start_joint_correction = &start_correction;
		twobone_ikjob.mid_joint_correction = &mid_correction;

		if (!twobone_ikjob.Run()) {
			return false;
		}

		mul_quaternion(ikdata.joints[0], start_correction, bp.pose);
		mul_quaternion(ikdata.joints[1], mid_correction, bp.pose);

		return do_ltm(ske, bp.pose, result.pose, nullptr, ikdata.joints[0]);
	} else {
		ozz::animation::IKAimJob aimjob;
		aimjob.target 		= ikdata.target;
		aimjob.pole_vector 	= ikdata.pole_vector;
		aimjob.up 			= ikdata.updir;
		aimjob.forward		= ikdata.forward;
		aimjob.offset 		= ikdata.offset;

		aimjob.joint		= get_joint(ikdata.joints[0]);
		aimjob.twist_angle	= ikdata.twist_angle;
		aimjob.weight		= ikdata.weight;

		ozz::math::SimdQuaternion correction;
		aimjob.joint_correction = &correction;

		if (!aimjob.Run()){
			return false;
		}

		mul_quaternion(ikdata.joints[0], correction, bp.pose);
		return do_ltm(ske, bp.pose, result.pose, nullptr, ikdata.joints[0]);
	}

	return 0;
}