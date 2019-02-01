#include <ozz/base/platform.h>
#include <ozz/base/maths/simd_math.h>
#include <ozz/base/maths/soa_transform.h>
#include <ozz/base/containers/vector.h>

namespace ozz {
	namespace animation {
		class Skeleton;
	}
}

struct hierarchy_build_data {
	ozz::animation::Skeleton *skeleton;
};

struct animation_result {
	ozz::Vector<ozz::math::Float4x4>::Std	joints;
};

struct bind_pose {
	ozz::Vector<ozz::math::SoaTransform>::Std	pose;
};