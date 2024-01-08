#include <core/ElementAnimation.h>
#include <core/Element.h>
#include <core/Transform.h>
#include <css/StyleSheet.h>
#include <util/Log.h>
#include <algorithm>
#include <bee/nonstd/unreachable.h>

namespace Rml {

static PropertyView Interpolate(PropertyId id, const PropertyView& p0, const PropertyView& p1, float alpha) {
	auto parser0 = p0.CreateParser();
	auto parser1 = p1.CreateParser();
	uint8_t type0 = parser0.pop<uint8_t>();
	uint8_t type1 = parser1.pop<uint8_t>();
	if (type0 != type1) {
		return InterpolateFallback(p0, p1, alpha);
	}
	switch (type0) {
	case (uint8_t)variant_index<Property, PropertyFloat>(): {
		auto v0 = parser0.pop<PropertyFloat>();
		auto v1 = parser1.pop<PropertyFloat>();
		auto v2 = v0.Interpolate(v1, alpha);
		return PropertyView { id, v2 };
	}
	case (uint8_t)variant_index<Property, Color>(): {
		auto v0 = parser0.pop<Color>();
		auto v1 = parser1.pop<Color>();
		auto v2 = v0.Interpolate(v1, alpha);
		return PropertyView { id, v2 };
	}
	case (uint8_t)variant_index<Property, Transform>(): {
		auto v0 = PropertyDecode(tag_v<Transform>, parser0);
		auto v1 = PropertyDecode(tag_v<Transform>, parser1);
		auto v2 = v0.Interpolate(v1, alpha);
		return PropertyView { id, v2 };
	}
	default:
		return InterpolateFallback(p0, p1, alpha);
	}
}

ElementInterpolate::ElementInterpolate(Element& element, PropertyId id, const PropertyView& in_prop, const PropertyView& out_prop)
	: id(id) {
	Reset(element, in_prop, out_prop);
}

void ElementInterpolate::Reset(Element& element, const PropertyView& in_prop, const PropertyView& out_prop) {
	auto parser0 = p0.CreateParser();
	auto parser1 = p1.CreateParser();
	uint8_t type0 = parser0.pop<uint8_t>();
	uint8_t type1 = parser1.pop<uint8_t>();
	if (type0 == (uint8_t)variant_index<Property, Transform>() && type1 == (uint8_t)variant_index<Property, Transform>()) {
		auto t0 = PropertyDecode(tag_v<Transform>, parser0);
		auto t1 = PropertyDecode(tag_v<Transform>, parser1);
		switch (PrepareTransformPair(t0, t1, element)) {
		case PrepareResult::Failed:
		case PrepareResult::NoChanged:
			p0 = in_prop;
			p1 = out_prop;
			break;
		case PrepareResult::ChangedAll:
			p0 = PropertyView { id, t0 };
			p1 = PropertyView { id, t1 };
			break;
		case PrepareResult::ChangedT0:
			p0 = PropertyView { id, t0 };
			p1 = out_prop;
			break;
		case PrepareResult::ChangedT1:
			p0 = in_prop;
			p1 = PropertyView { id, t1 };
			break;
		default:
			std::unreachable();
		}
	}
}

PropertyView ElementInterpolate::Update(float t0, float t1, float t, const Tween& tween) {
	float alpha = 0.0f;
	const float eps = 1e-3f;
	if (t1 - t0 > eps)
		alpha = (t - t0) / (t1 - t0);
	alpha = std::clamp(alpha, 0.0f, 1.0f);
	alpha = tween.get(alpha);
	if (alpha > 1.f) alpha = 1.f;
	if (alpha < 0.f) alpha = 0.f;
	return Interpolate(id, p0, p1, alpha);
}

ElementTransition::ElementTransition(Element& element, PropertyId id, const Transition& transition, const PropertyView& in_prop, const PropertyView& out_prop)
	: transition(transition)
	, interpolate(element, id, in_prop, out_prop)
	, time(transition.delay)
	, complete(false)
{}

PropertyView ElementTransition::UpdateProperty(float delta) {
	time += delta;
	if (time >= transition.duration) {
		complete = true;
		time = transition.duration;
	}
	const float t = time / transition.duration;
	return interpolate.Update(0.0f, 1.0f, t, transition.tween);
}

ElementAnimation::ElementAnimation(Element& element, PropertyId id, const Animation& animation, const Keyframe& keyframe)
	: animation(animation)
	, keyframe(keyframe)
	, interpolate(element, id, keyframe[0].prop, keyframe[1].prop)
	, time(animation.transition.delay)
	, current_iteration(0)
	, key(1)
	, complete(false)
	, reverse_direction(false)
{}

PropertyView ElementAnimation::UpdateProperty(Element& element, float delta) {
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
		interpolate.Reset(element, keyframe[key-1].prop, keyframe[key].prop);
	}
	const float t0 = keyframe[key-1].time;
	const float t1 = keyframe[key].time;
	return interpolate.Update(t0, t1, t, animation.transition.tween);
}

}
