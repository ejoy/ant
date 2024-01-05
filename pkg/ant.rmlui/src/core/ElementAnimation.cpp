#include <core/ElementAnimation.h>
#include <core/Element.h>
#include <core/Transform.h>
#include <css/StyleSheet.h>
#include <util/Log.h>
#include <algorithm>

namespace Rml {

ElementInterpolate::ElementInterpolate(Element& element, const Property& in_prop, const Property& out_prop)
	: p0(in_prop)
	, p1(out_prop) {
	if (in_prop.Has<Transform>() && out_prop.Has<Transform>()) {
		auto& t0 = p0.GetRef<Transform>();
		auto& t1 = p1.GetRef<Transform>();
		PrepareTransformPair(t0, t1, element);
	}
}

ElementInterpolate::ElementInterpolate(Element& element, const PropertyRaw& in_prop, const PropertyRaw& out_prop)
	: p0(*in_prop.Decode())
	, p1(*out_prop.Decode()) {
	if (in_prop.Has<Transform>() && out_prop.Has<Transform>()) {
		auto& t0 = p0.GetRef<Transform>();
		auto& t1 = p1.GetRef<Transform>();
		PrepareTransformPair(t0, t1, element);
	}
}

Property ElementInterpolate::Update(float t0, float t1, float t, const Tween& tween) {
	float alpha = 0.0f;
	const float eps = 1e-3f;
	if (t1 - t0 > eps)
		alpha = (t - t0) / (t1 - t0);
	alpha = std::clamp(alpha, 0.0f, 1.0f);
	alpha = tween.get(alpha);
	if (alpha > 1.f) alpha = 1.f;
	if (alpha < 0.f) alpha = 0.f;
	return p0.Interpolate(p1, alpha);
}

ElementTransition::ElementTransition(Element& element, const Transition& transition, const PropertyRaw& in_prop, const PropertyRaw& out_prop)
	: transition(transition)
	, interpolate(element, in_prop, out_prop)
	, time(transition.delay)
	, complete(false)
{}

Property ElementTransition::UpdateProperty(float delta) {
	time += delta;
	if (time >= transition.duration) {
		complete = true;
		time = transition.duration;
	}
	const float t = time / transition.duration;
	return interpolate.Update(0.0f, 1.0f, t, transition.tween);
}

ElementAnimation::ElementAnimation(Element& element, const Animation& animation, const Keyframe& keyframe)
	: animation(animation)
	, keyframe(keyframe)
	, interpolate(element, keyframe[0].prop, keyframe[1].prop)
	, time(animation.transition.delay)
	, current_iteration(0)
	, key(1)
	, complete(false)
	, reverse_direction(false)
{}

Property ElementAnimation::UpdateProperty(Element& element, float delta) {
	time += delta;

	if (time >= animation.transition.duration) {
		current_iteration += 1;
		if (animation.num_iterations == -1 || (current_iteration >= 0 && current_iteration < animation.num_iterations)) {
			time -= animation.transition.duration;
			if (animation.alternate)
				reverse_direction = !reverse_direction;
		}
		else {
			complete = true;
			time = animation.transition.duration;
		}
	}

	const float t = reverse_direction
		? animation.transition.duration - time / animation.transition.duration
		: time / animation.transition.duration
		;
	uint8_t n = (uint8_t)keyframe.size();
	uint8_t newkey = n;
	for (uint8_t i = 1; i < n; ++i) {
		if (t <= keyframe[i].time) {
			newkey = i;
			break;
		}
	}
	if (newkey != key) {
		key = newkey;
		interpolate = ElementInterpolate { element, keyframe[key-1].prop, keyframe[key].prop };
	}
	const float t0 = keyframe[key-1].time;
	const float t1 = keyframe[key].time;
	return interpolate.Update(t0, t1, t, animation.transition.tween);
}

}
