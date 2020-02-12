#include "hierarchy.h"

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
#include <lua.hpp>

#ifdef _DEBUG
#define verfiy(_c, _check)	assert((_c) == _check)
#else
#define verfiy(_c, _check)	(_c)
#endif // _DEBUG

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

void fetch_ikdata(lua_State* L, int idx, ik_data& ikdata) {
	luaL_checktype(L, idx, LUA_TTABLE);

	lua_getfield(L, idx, "type");
	ikdata.type = lua_tostring(L, -1);
	lua_pop(L, 1);

	auto get_vec = [L](int idx, auto name, auto* result) {
		if (LUA_TNIL != lua_getfield(L, idx, name)) {
			auto p = (const float*)lua_touserdata(L, -1);
			for (size_t ii = 0; ii < 4; ++ii) {
				*result++ = p[ii];
			}
			lua_pop(L, 1);
		}
	};

	// define in model space
	get_vec(idx, "target", (float*)(&ikdata.target));
	get_vec(idx, "pole_vector", (float*)(&ikdata.pole_vector));

	auto get_number = [L](int idx, auto name) {
		if (lua_getfield(L, idx, name) == LUA_TNUMBER){
			const float value = (float)lua_tonumber(L, -1);
			lua_pop(L, 1);
			return value;
		}

		luaL_error(L, "%s must be a number from lua", name);
		return 0.f;
	};

	ikdata.weight = get_number(idx, "weight");
	ikdata.twist_angle = get_number(idx, "twist_angle");

	if (lua_getfield(L, idx, "joint_indices") == LUA_TTABLE) {
		const lua_Integer len = lua_rawlen(L, -1);
		if (len <= 0 || len > 3) {
			luaL_error(L, "ik joints data must be in (0, 3], %d", len);
		}
		for (lua_Integer ii = 0; ii < len; ++ii) {
			lua_geti(L, -1, ii + 1);
			ikdata.joints[ii] = (uint16_t)lua_tointeger(L, -1) - 1;
			lua_pop(L, 1);
		}
	}
	else {
		luaL_error(L, "joints field must be 'table'");
	}
	lua_pop(L, 1);

	if (ikdata.type == "two_bone") {
		ikdata.soften = get_number(idx, "soften");
		get_vec(idx, "mid_axis", (float*)(&ikdata.mid_axis));
	}
	else if (ikdata.type == "aim") {
		get_vec(idx, "up_axis", (float*)(&ikdata.up_axis));
		get_vec(idx, "forward", (float*)(&ikdata.forward));
		get_vec(idx, "offset", (float*)(&ikdata.offset));
	}
	else {
		luaL_error(L, "not support type:%s", ikdata.type.c_str());
	}
}

bool
do_ik(lua_State* L,
	const ozz::animation::Skeleton *ske,
	bind_pose_soa::bind_pose_type &pose_soa, 
	bind_pose::bind_pose_type &result_pose) {

	ik_data ikdata;
	fetch_ikdata(L, -1, ikdata);

	auto get_joint = [&result_pose](int jointidx) {
		if (jointidx < 0 || jointidx > result_pose.size()){
			return (ozz::math::Float4x4*)nullptr;
		}

		return &result_pose[jointidx];
	};

	if (ikdata.type == "two_bone"){
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

		mul_quaternion(ikdata.joints[0], start_correction, pose_soa);
		mul_quaternion(ikdata.joints[1], mid_correction, pose_soa);
	} else {
		ozz::animation::IKAimJob aimjob;
		aimjob.target 		= ikdata.target;
		aimjob.pole_vector 	= ikdata.pole_vector;
		aimjob.up 			= ikdata.up_axis;
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

		mul_quaternion(ikdata.joints[0], correction, pose_soa);
	}

	ozz::animation::LocalToModelJob job;
	job.input = ozz::make_range(pose_soa);
	job.skeleton = ske;
	job.output = ozz::make_range(result_pose);
	job.from = ikdata.joints[0];
	return job.Run();
}
