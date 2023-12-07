#include <ozz/base/platform.h>
#include <ozz/base/maths/simd_math.h>
#include <ozz/base/maths/soa_transform.h>
#include <ozz/base/containers/vector.h>
#include <ozz/base/maths/vec_float.h>
#include <ozz/base/maths/quaternion.h>
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

using bindpose_soa = ozz::vector<ozz::math::SoaTransform>;
using bindpose = ozz::vector<ozz::math::Float4x4>;
