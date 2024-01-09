#pragma once

#include <css/Property.h>
#include <core/Tween.h>
#include <core/ID.h>
#include <css/StyleSheet.h>

namespace Rml {

class ElementInterpolate {
public:
	ElementInterpolate(Element& element, PropertyId id, const Property& in_prop, const Property& out_prop);
	void Reset(Element& element, const Property& in_prop, const Property& out_prop);
	Property Update(float t0, float t1, float t, const Tween& tween);
private:
	PropertyId id;
	PropertyRef p0;
	PropertyRef p1;
};

class ElementTransition {
public:
	ElementTransition(Element& element, PropertyId id, const Transition& transition, const Property& in_prop, const Property& out_prop);
	Property UpdateProperty(float delta);
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
	Property UpdateProperty(Element& element, float delta);
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
