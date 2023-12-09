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

struct ozzAnimation {
	ozz::animation::Animation* v;
	ozz::animation::SamplingJob::Context* sampling_context;
	ozzAnimation()
		: v(ozz::New<ozz::animation::Animation>())
		, sampling_context(nullptr) {
	}
	ozzAnimation(ozz::animation::Animation* p)
		: v(p)
		, sampling_context(nullptr) {
		createSamplingContext();
	}
	~ozzAnimation() {
		ozz::Delete(v);
		if (sampling_context) {
			ozz::Delete(sampling_context);
		}
	}
	void createSamplingContext() {
		assert(v && !sampling_context);
		sampling_context = ozz::New<ozz::animation::SamplingJob::Context>(v->num_tracks());
	}
};

struct ozzRawAnimation {
	ozz::animation::offline::RawAnimation* v;
	ozzRawAnimation()
		: v(ozz::New<ozz::animation::offline::RawAnimation>())
	{}
	~ozzRawAnimation() {
		ozz::Delete(v);
	}
};

struct ozzSkeleton {
	ozz::animation::Skeleton* v;
	ozzSkeleton(ozz::animation::Skeleton* p)
		: v(p) {
	}
	ozzSkeleton()
		: v(ozz::New<ozz::animation::Skeleton>()) {
	}
	~ozzSkeleton() {
		ozz::Delete(v);
	}
};
