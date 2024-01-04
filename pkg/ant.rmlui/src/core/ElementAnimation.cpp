#include <core/ElementAnimation.h>
#include <core/Element.h>
#include <core/Transform.h>
#include <util/Log.h>
#include <algorithm>

namespace Rml {

//
// see
//   https://www.w3.org/TR/css-transforms-1/#interpolation-of-transforms
//   https://www.w3.org/TR/css-transforms-2/#interpolation-of-transform-functions
//
static bool PrepareTransformPair(Transform& t0, Transform& t1, Element& element) {
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

static bool PrepareTransforms(Property& prop0, Property& prop1, Element& element) {
	if (!prop0.Has<Transform>() || !prop1.Has<Transform>()) {
		return true;
	}
	auto& t0 = prop0.GetRef<Transform>();
	auto& t1 = prop1.GetRef<Transform>();
	if (!PrepareTransformPair(t0, t1, element)) {
		Log::Message(Log::Level::Warning, "Property is not interpolation.");
		//TODO
		//Log::Message(Log::Level::Warning, "Property '%s' is not interpolation with property '%s'.", prop1.ToString().c_str(), prop0.ToString().c_str());
		return false;
	}
	return true;
}

static bool AllowInterpolate(Property& prop, Element& element) {
	if (!prop.AllowInterpolate(element)) {
		Log::Message(Log::Level::Warning, "Property is not a valid target for interpolation.");
		//TODO
		//Log::Message(Log::Level::Warning, "Property '%s' is not a valid target for interpolation.", prop.ToString().c_str());
		return false;
	}
	return true;
}

static void InterpolateProperty(Element& element, PropertyId id, const Property& p0, const Property& p1, float t0, float t1, float t, const Tween& tween) {
	float alpha = 0.0f;
	const float eps = 1e-3f;
	if (t1 - t0 > eps)
		alpha = (t - t0) / (t1 - t0);
	alpha = std::clamp(alpha, 0.0f, 1.0f);
	alpha = tween.get(alpha);
	if (alpha > 1.f) alpha = 1.f;
	if (alpha < 0.f) alpha = 0.f;
	Property p2 = p0.Interpolate(p1, alpha);
	element.SetAnimationProperty(id, p2);
}

ElementTransition::ElementTransition(const Property& in_prop, const Property& out_prop, const Transition& transition)
	: in_prop(in_prop)
	, out_prop(out_prop)
	, time(transition.delay)
	, duration(transition.duration)
	, tween(transition.tween)
	, animation_complete(false)
{}

bool ElementTransition::IsValid(Element& element) {
	if (duration < 1e-3f) {
		Log::Message(Log::Level::Warning, "Animation duration too samll.");
		return false;
	}
	if (!AllowInterpolate(in_prop, element)) {
		return false;
	}
	if (!AllowInterpolate(out_prop, element)) {
		return false;
	}
	if (!PrepareTransforms(in_prop, out_prop, element)) {
		return false;
	}
	return true;
}

void ElementTransition::UpdateProperty(Element& element, PropertyId id, float t) {
	const float t0 = 0.0f;
	const float t1 = 1.0f;
	const Property& p0 = in_prop;
	const Property& p1 = out_prop;
	InterpolateProperty(element, id, p0, p1, t0, t1, t, tween);
}

void ElementTransition::Update(Element& element, PropertyId id, float delta) {
	if (animation_complete || delta <= 0.0f)
		return;
	time += delta;
	if (time >= duration) {
		animation_complete = true;
		time = duration;
	}
	UpdateProperty(element, id, time/duration);
}

ElementAnimation::ElementAnimation(const Property& in_prop, const Property& out_prop, const Animation& animation)
	: ElementTransition(in_prop, out_prop, animation.transition)
	, name(animation.name)
	, keys()
	, num_iterations(animation.num_iterations)
	, current_iteration(0)
	, alternate_direction(animation.alternate)
	, reverse_direction(false)
{}

void ElementAnimation::AddKey(float time, const Property& prop) {
	keys.emplace_back(time, prop);
}

bool ElementAnimation::IsValid(Element& element) {
	if (duration < 1e-3f) {
		Log::Message(Log::Level::Warning, "Animation duration too samll.");
		return false;
	}
	if (!AllowInterpolate(in_prop, element)) {
		return false;
	}
	if (!AllowInterpolate(out_prop, element)) {
		return false;
	}
	for (auto& key : keys) {
		if (!AllowInterpolate(key.prop, element)) {
			return false;
		}
	}
	//TODO: PrepareTransformPair
	return true;
}

void ElementAnimation::UpdateProperty(Element& element, PropertyId id, float t) {
	const size_t n = keys.size();
	size_t key = n;
	for (size_t i = 0; i < keys.size(); ++i) {
		if (t <= keys[i].time) {
			key = i;
			break;
		}
	}
	const float t0 = (key==0)? 0.0f: keys[key-1].time;
	const float t1 = (key==n)? 1.0f: keys[key].time;
	const Property& p0 = (key==0)? in_prop: keys[key-1].prop;
	const Property& p1 = (key==n)? out_prop: keys[key].prop;
	InterpolateProperty(element, id, p0, p1, t0, t1, t, tween);
}

void ElementAnimation::Update(Element& element, PropertyId id, float delta) {
	if (animation_complete || delta <= 0.0f)
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

	if (reverse_direction) {
		UpdateProperty(element, id,  duration - time/duration);
	}
	else {
		UpdateProperty(element, id, time/duration);
	}
}

}
