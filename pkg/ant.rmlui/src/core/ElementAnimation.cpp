#include <core/ElementAnimation.h>
#include <core/Element.h>
#include <core/Transform.h>
#include <css/StyleSheet.h>
#include <util/Log.h>
#include <algorithm>

namespace Rml {

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

ElementAnimation::ElementAnimation(const Animation& animation, const Keyframe& keyframe)
	: animation(animation)
	, keyframe(keyframe)
	, time(animation.transition.delay)
	, current_iteration(0)
	, animation_complete(false)
	, reverse_direction(false)
{
	//TODO
	//PrepareTransforms
}

void ElementAnimation::UpdateProperty(Element& element, PropertyId id, float t) {
	auto const& keys = keyframe.keys;
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
	const Property& p0 = (key==0)? *keyframe.from: keys[key-1].prop;
	const Property& p1 = (key==n)? *keyframe.to: keys[key].prop;
	InterpolateProperty(element, id, p0, p1, t0, t1, t, animation.transition.tween);
}

void ElementAnimation::Update(Element& element, PropertyId id, float delta) {
	if (animation_complete || delta <= 0.0f)
		return;
	time += delta;

	if (time >= animation.transition.duration) {
		current_iteration += 1;
		if (animation.num_iterations == -1 || (current_iteration >= 0 && current_iteration < animation.num_iterations)) {
			time -= animation.transition.duration;
			if (animation.alternate)
				reverse_direction = !reverse_direction;
		}
		else {
			animation_complete = true;
			time = animation.transition.duration;
		}
	}

	if (reverse_direction) {
		UpdateProperty(element, id,  animation.transition.duration - time/animation.transition.duration);
	}
	else {
		UpdateProperty(element, id, time/animation.transition.duration);
	}
}

}
