#include <core/ElementAnimation.h>
#include <core/Element.h>
#include <core/Transform.h>
#include <css/StyleSheet.h>
#include <util/Log.h>
#include <algorithm>
#include <bee/nonstd/unreachable.h>

namespace Rml {

struct InterpolateVisitor {
	PropertyId id;
	const Property& p0;
	const Property& p1;
	float alpha;
	Property operator()() {
		return InterpolateFallback(p0, p1, alpha);
	}
	template <typename T>
	Property operator()(const T&, const T&) {
		return InterpolateFallback(p0, p1, alpha);
	}
	template <typename T>
	Property operator()(tag<T>, PropertyBasicView, PropertyBasicView) {
		return InterpolateFallback(p0, p1, alpha);
	}
	Property operator()(const PropertyFloat& v0, const PropertyFloat& v1) {
		auto v2 = v0.Interpolate(v1, alpha);
		return Property { id, v2 };
	}
	Property operator()(const Color& v0, const Color& v1) {
		auto v2 = v0.Interpolate(v1, alpha);
		return Property { id, v2 };
	}
	Property operator()(tag<Transform>, PropertyBasicView view0, PropertyBasicView view1) {
		auto v0 = PropertyDecode(tag_v<Transform>, view0);
		auto v1 = PropertyDecode(tag_v<Transform>, view1);
		auto v2 = v0.Interpolate(v1, alpha);
		return Property { id, v2 };
	}
};

ElementInterpolate::ElementInterpolate(Element& element, PropertyId id, const Property& in_prop, const Property& out_prop)
	: id(id) {
	Reset(element, in_prop, out_prop);
}

void ElementInterpolate::Reset(Element& element, const Property& in_prop, const Property& out_prop) {
	auto t0 = p0.GetIf<Transform>();
	auto t1 = p1.GetIf<Transform>();
	if (t0 && t1) {
		switch (PrepareTransformPair(*t0, *t1, element)) {
		case PrepareResult::Failed:
		case PrepareResult::NoChanged:
			p0 = in_prop;
			p1 = out_prop;
			break;
		case PrepareResult::ChangedAll:
			p0 = Property { id, *t0 };
			p1 = Property { id, *t1 };
			break;
		case PrepareResult::ChangedT0:
			p0 = Property { id, *t0 };
			p1 = out_prop;
			break;
		case PrepareResult::ChangedT1:
			p0 = in_prop;
			p1 = Property { id, *t1 };
			break;
		default:
			std::unreachable();
		}
	}
	else {
		p0 = in_prop;
		p1 = out_prop;
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
	return PropertyVisit(InterpolateVisitor { id, p0, p1, alpha }, p0, p1);
}

ElementTransition::ElementTransition(Element& element, PropertyId id, const Transition& transition, const Property& in_prop, const Property& out_prop)
	: transition(transition)
	, interpolate(element, id, in_prop, out_prop)
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
		interpolate.Reset(element, keyframe[key-1].prop, keyframe[key].prop);
	}
	const float t0 = keyframe[key-1].time;
	const float t1 = keyframe[key].time;
	return interpolate.Update(t0, t1, t, animation.transition.tween);
}

}
