#include <ozz/base/platform.h>
#include <ozz/base/maths/simd_math.h>
#include <ozz/base/maths/soa_transform.h>
#include <ozz/base/containers/vector.h>
#include <string>

namespace ozz {
	namespace animation {
		class Skeleton;
	}
}

struct hierarchy_build_data {
	ozz::animation::Skeleton *skeleton;
};

template<typename T>
struct bind_pose_T{
	using bind_pose_type = typename ozz::Vector<T>::Std;
	typename ozz::Vector<T>::Std pose;
};

using bind_pose 	= bind_pose_T<ozz::math::Float4x4>;
using bind_pose_soa = bind_pose_T<ozz::math::SoaTransform>;

struct ik_data{
	std::string 				type;
	ozz::math::SimdFloat4		target;
	ozz::math::SimdFloat4		pole_vector;
	union{
		ozz::math::SimdFloat4	updir;
		ozz::math::SimdFloat4	mid_axis;
	};
	
	
	ozz::math::SimdFloat4		forward;
	ozz::math::SimdFloat4		offset;
	
	float 						weight;
	float 						twist_angle;
	float 						soften;
	uint16_t					joints[3];
};