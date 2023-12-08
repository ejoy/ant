#pragma once

#include <ozz/base/containers/vector.h>
#include <ozz/base/maths/simd_math.h>
#include <ozz/base/maths/soa_transform.h>

#include <ozz/animation/runtime/animation.h>
#include <ozz/animation/runtime/blending_job.h>
#include <ozz/animation/runtime/sampling_job.h>
#include <ozz/animation/runtime/skeleton.h>
#include <ozz/animation/offline/raw_animation.h>

struct ozzJointRemap {
	ozz::vector<uint16_t> joints;
};

struct ozzSamplingContext {
	ozz::animation::SamplingJob::Context*  v;
	ozzSamplingContext(int max_tracks)
	: v(ozz::New<ozz::animation::SamplingJob::Context>(max_tracks))
	{ }
	~ozzSamplingContext() {
		ozz::Delete(v);
	}
};

struct ozzBindpose: public ozz::vector<ozz::math::Float4x4> {
	ozzBindpose(size_t numjoints)
		: ozz::vector<ozz::math::Float4x4>(numjoints)
	{}
	ozzBindpose(size_t numjoints, const float* data)
		: ozz::vector<ozz::math::Float4x4>(numjoints) {
		memcpy(&(*this)[0], data, sizeof(ozz::math::Float4x4) * numjoints);
	}
};

struct ozzPoseResult: public ozzBindpose {
	ozz::vector<ozz::vector<ozz::math::SoaTransform>> m_results;
	ozz::vector<ozz::animation::BlendingJob::Layer> m_layers;
	ozz::animation::Skeleton* m_ske = nullptr;
	ozzPoseResult(size_t numjoints)
		: ozzBindpose(numjoints)
	{}
	ozzPoseResult(size_t numjoints, const float* data)
		: ozzBindpose(numjoints, data)
	{}
};

struct ozzAnimation {
	ozz::animation::Animation* v;
	ozzAnimation(ozz::animation::Animation* p)
		: v(p) {
	}
	~ozzAnimation() {
		ozz::Delete(v);
	}
};

struct ozzRawAnimation {
	ozz::animation::offline::RawAnimation* v;
	ozz::animation::Skeleton* m_skeleton;
	ozzRawAnimation()
		: v(ozz::New<ozz::animation::offline::RawAnimation>())
		, m_skeleton(nullptr)
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
	~ozzSkeleton() {
		ozz::Delete(v);
	}
};
