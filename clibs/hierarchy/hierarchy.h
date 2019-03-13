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

using result_poses = ozz::Vector<ozz::math::Float4x4>::Std;
struct bindpose_result {
	result_poses	pose;
};

using soa_poses = ozz::Vector<ozz::math::SoaTransform>::Std;
struct bind_pose {
	soa_poses pose;
};