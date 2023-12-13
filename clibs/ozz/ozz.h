#pragma once

#include <ozz/base/containers/vector.h>
#include <ozz/base/maths/simd_math.h>
#include <ozz/base/maths/soa_transform.h>

#include <ozz/animation/runtime/animation.h>
#include <ozz/animation/runtime/blending_job.h>
#include <ozz/animation/runtime/sampling_job.h>
#include <ozz/animation/runtime/skeleton.h>
#include <ozz/animation/offline/raw_animation.h>

struct ozzUint16Verctor: public ozz::vector<uint16_t> {
	ozzUint16Verctor()
		: ozz::vector<uint16_t>()
	{}
	ozzUint16Verctor(size_t n)
		: ozz::vector<uint16_t>(n)
	{}
	ozzUint16Verctor(size_t n, const uint16_t* data)
		: ozz::vector<uint16_t>(n) {
		memcpy(&(*this)[0], data, sizeof(uint16_t) * n);
	}
};

struct ozzMatrixVector: public ozz::vector<ozz::math::Float4x4> {
	ozzMatrixVector()
		: ozz::vector<ozz::math::Float4x4>()
	{}
	ozzMatrixVector(size_t n)
		: ozz::vector<ozz::math::Float4x4>(n)
	{}
	ozzMatrixVector(size_t n, const float* data)
		: ozz::vector<ozz::math::Float4x4>(n) {
		memcpy(&(*this)[0], data, sizeof(ozz::math::Float4x4) * n);
	}
};

struct ozzSoaTransformVector: public ozz::vector<ozz::math::SoaTransform> {
	ozzSoaTransformVector(size_t n)
		: ozz::vector<ozz::math::SoaTransform>(n)
	{}
};

struct ozzSamplingJobContext: public ozz::animation::SamplingJob::Context {
	ozzSamplingJobContext(int n)
		: ozz::animation::SamplingJob::Context(n) {
	}
};

struct ozzAnimation: public ozz::animation::Animation {
	ozzAnimation()
		: ozz::animation::Animation(){
	}
	ozzAnimation(ozz::animation::Animation&& v)
		: ozz::animation::Animation(std::move(v)) {
	}
};

struct ozzRawAnimation: public ozz::animation::offline::RawAnimation {
};

struct ozzSkeleton : public ozz::animation::Skeleton {
};
