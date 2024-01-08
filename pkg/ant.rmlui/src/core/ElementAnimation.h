#pragma once

#include <css/Property.h>
#include <css/PropertyView.h>
#include <core/Tween.h>
#include <core/ID.h>
#include <css/StyleSheet.h>

namespace Rml {

class ElementInterpolate {
public:
	ElementInterpolate(Element& element, const PropertyView& in_prop, const PropertyView& out_prop);
	~ElementInterpolate();
	ElementInterpolate(ElementInterpolate&& rhs)
		: p0(rhs.p0)
		, p1(rhs.p1) {
		rhs.p0 = {};
		rhs.p1 = {};
	}
	ElementInterpolate& operator=(ElementInterpolate&& rhs) {
		if (this != &rhs) {
			p0 = rhs.p0;
			p1 = rhs.p1;
			rhs.p0 = {};
			rhs.p1 = {};
		}
		return *this;
	}
	ElementInterpolate(const ElementInterpolate&) = delete;
	ElementInterpolate& operator=(const ElementInterpolate&) = delete;
	PropertyView Update(float t0, float t1, float t, const Tween& tween);
private:
	PropertyView p0;
	PropertyView p1;
};

class ElementTransition {
public:
	ElementTransition(Element& element, const Transition& transition, const PropertyView& in_prop, const PropertyView& out_prop);
	PropertyView UpdateProperty(float delta);
	bool IsComplete() const { return complete; }
	float GetTime() const { return time; }
private:
	Transition transition;
	ElementInterpolate interpolate;
	float time;
	bool complete;
};

class ElementAnimation {
public:
	ElementAnimation(Element& element, PropertyId id, const Animation& animation, const Keyframe& keyframe);
	PropertyView UpdateProperty(Element& element, PropertyId id, float delta);
	const std::string& GetName() const { return animation.name; }
	bool IsComplete() const { return complete; }
	float GetTime() const { return time; }
private:
	const Animation animation;
	const Keyframe& keyframe;
	ElementInterpolate interpolate;
	float time;
	int current_iteration;
	uint8_t key;
	bool complete;
	bool reverse_direction;
};

}
