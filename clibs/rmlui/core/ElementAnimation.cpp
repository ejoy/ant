#include <core/ElementAnimation.h>
#include <core/Element.h>
#include <core/Transform.h>
#include <core/Log.h>
#include <algorithm>

namespace Rml {

//
// see
//   https://www.w3.org/TR/css-transforms-1/#interpolation-of-transforms
//   https://www.w3.org/TR/css-transforms-2/#interpolation-of-transform-functions
//
static bool PrepareTransformPair(Transform& t0, Transform& t1, Element& element) {
	for (auto& p0 : t0) {
		if (!p0.PrepareForInterpolation(element)) {
			return false;
		}
	}
	for (auto& p1 : t1) {
		if (!p1.PrepareForInterpolation(element)) {
			return false;
		}
	}

	if (t0.size() != t1.size()) {
		bool t0_shorter = t0.size() < t1.size();
		auto& shorter = t0_shorter ? t0 : t1;
		auto& longer = t0_shorter ? t1 : t0;
		size_t i = 0;
		for (; i < shorter.size(); ++i) {
			auto& p0 = shorter[i];
			auto& p1 = longer[i];
			if (p0.index() == p1.index()) {
				continue;
			}
			if (p0.GetType() == p1.GetType()) {
				p0.ConvertToGenericType();
				p1.ConvertToGenericType();
				assert(p0.index() == p1.index());
				continue;
			}
			if (shorter.size() < longer.size()) {
				TransformPrimitive p = p1;
				p.SetIdentity();
				shorter.insert(shorter.begin() + i, p);
				continue;
			}
			return t0.Combine(element, i) && t1.Combine(element, i);
		}
		for (; i < longer.size(); ++i) {
			auto& p1 = longer[i];
			TransformPrimitive p = p1;
			p.SetIdentity();
			shorter.insert(shorter.begin() + i, p);
		}
		return true;
	}

	assert(t0.size() == t1.size());
	for (size_t i = 0; i < t0.size(); ++i) {
		if (t0[i].index() != t1[i].index()) {
			return t0.Combine(element, i) && t1.Combine(element, i);
		}
	}
	return true;
}

static bool PrepareTransforms(AnimationKey& key, Element& element) {
	auto& prop0 = key.in;
	auto& prop1 = key.out;
	if (!prop0.Has<Transform>() || !prop1.Has<Transform>()) {
		return false;
	}
	auto& t0 = prop0.Get<Transform>();
	auto& t1 = prop1.Get<Transform>();
	return PrepareTransformPair(t0, t1, element);
}

ElementAnimation::ElementAnimation(PropertyId property_id, ElementAnimationOrigin origin, float start_time, int num_iterations, bool alternate_direction)
	: property_id(property_id)
	, duration(0.f)
	, num_iterations(num_iterations)
	, alternate_direction(alternate_direction)
	, time(start_time)
	, current_iteration(0)
	, reverse_direction(false)
	, animation_complete(false)
	, origin(origin)
{}

bool ElementAnimation::AddKey(float target_time, const Property& out_prop, Element& element, Tween tween) {
	if (!out_prop.AllowInterpolate()) {
		Log::Message(Log::Level::Warning, "Property '%s' is not a valid target for interpolation.", out_prop.ToString().c_str());
		return false;
	}
	if (keys.size() == 0) {
		keys.emplace_back(target_time, out_prop, out_prop, tween);
		duration = target_time;
		return true;
	}
	Property const& in_prop = keys.back().prop;
	keys.emplace_back(target_time, in_prop, out_prop, tween);
	if (out_prop.Has<Transform>()) {
		if (!PrepareTransforms(keys.back(), element)) {
			Log::Message(Log::Level::Warning, "Could not add animation key with property '%s'.", out_prop.ToString().c_str());
			keys.pop_back();
			return false;
		}
	}
	duration = target_time;
	return true;
}

float ElementAnimation::GetInterpolationFactorAndKeys(int* out_key) const {
	float t = time;

	if (reverse_direction)
		t = duration - t;

	int key0 = -1;
	int key1 = -1;

	{
		for (int i = 0; i < (int)keys.size(); i++) {
			if (keys[i].time >= t) {
				key1 = i;
				break;
			}
		}

		if (key1 < 0) key1 = (int)keys.size() - 1;
		key0 = (key1 == 0 ? 0 : key1 - 1);
	}

	assert(key0 >= 0 && key0 < (int)keys.size() && key1 >= 0 && key1 < (int)keys.size());
	float alpha = 0.0f;

	{
		const float t0 = keys[key0].time;
		const float t1 = keys[key1].time;
		const float eps = 1e-3f;
		if (t1 - t0 > eps)
			alpha = (t - t0) / (t1 - t0);
		alpha = std::clamp(alpha, 0.0f, 1.0f);
	}

	alpha = keys[key1].tween.get(alpha);
	if (out_key) *out_key = key1;
	return alpha;
}

void ElementAnimation::Update(Element& element, float delta) {
	if (keys.size() < 2 || animation_complete || delta <= 0.0f)
		return;
	time += delta;

	if (time >= duration) {
		current_iteration += 1;
		if (num_iterations == -1 || (current_iteration >= 0 && current_iteration < num_iterations)) {
			time -= duration;
			if (alternate_direction)
				reverse_direction = !reverse_direction;
		}
		else {
			animation_complete = true;
			time = duration;
		}
	}

	int key = -1;
	float alpha = GetInterpolationFactorAndKeys(&key);
	if (alpha > 1.f) alpha = 1.f;
	if (alpha < 0.f) alpha = 0.f;
	const Property& p0 = keys[key].in;
	const Property& p1 = keys[key].out;
	Property p2 = p0.Interpolate(p1, alpha);
	element.SetAnimationProperty(GetPropertyId(), p2);
}

void ElementAnimation::Release(Element& element) {
	if (!IsInitalized()) {
		return;
	}
	element.DelAnimationProperty(GetPropertyId());
}

}
