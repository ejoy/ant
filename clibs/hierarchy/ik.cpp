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

bool
do_ik(const ozz::animation::Skeleton *ske,
	const ik_data &ikdata,
	bind_pose_soa::bind_pose_type &pose_soa, 
	bind_pose::bind_pose_type &result_pose) {
	auto get_joint = [&result_pose](int jointidx) {
		if (jointidx < 0 || jointidx > result_pose.size()){
			return (ozz::math::Float4x4*)nullptr;
		}

		return &result_pose[jointidx];
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

	return do_ltm(ske, pose_soa, result_pose, nullptr, ikdata.joints[0]);
}