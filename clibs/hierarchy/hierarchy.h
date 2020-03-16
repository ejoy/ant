#include <ozz/base/platform.h>
#include <ozz/base/maths/simd_math.h>
#include <ozz/base/maths/soa_transform.h>
#include <ozz/base/containers/vector.h>
#include <ozz/animation/runtime/blending_job.h>
#include <string>

namespace ozz {
	namespace animation {
		class Skeleton;
	}
}

struct hierarchy_build_data {
	ozz::animation::Skeleton *skeleton;
};

using bindpose_soa = ozz::Vector<ozz::math::SoaTransform>::Std;
using bindpose = ozz::Vector<ozz::math::Float4x4>::Std;

struct ik_data{
	std::string 				type;
	ozz::math::SimdFloat4		target;
	ozz::math::SimdFloat4		pole_vector;
	union{
		ozz::math::SimdFloat4	up_axis;
		ozz::math::SimdFloat4	mid_axis;
	};
	
	
	ozz::math::SimdFloat4		forward;
	ozz::math::SimdFloat4		offset;
	
	float 						weight;
	float 						twist_angle;
	float 						soften;
	uint16_t					joints[3];
};