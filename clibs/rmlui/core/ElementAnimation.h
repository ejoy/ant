#pragma once

#include <core/Property.h>
#include <core/Tween.h>
#include <core/ID.h>

namespace Rml {

struct AnimationKey {
	AnimationKey(float time, const Property& prop)
		: time(time)
		, prop(prop)
	{}
	float time;
	Property prop;
};

class ElementTransition {
public:
	ElementTransition(const Property& in_prop, const Property& out_prop, const Transition& transition);
	void Update(Element& element, PropertyId id, float delta);
	bool IsComplete() const { return animation_complete; }
	bool IsValid(Element& element);
protected:
	void UpdateProperty(Element& element, PropertyId id, float time);
protected:
	Property in_prop;
	Property out_prop;
	float time;
	float duration;
	Tween tween;
	bool animation_complete;
};

class ElementAnimation: public ElementTransition {
public:
	ElementAnimation(const Property& in_prop, const Property& out_prop, const Animation& animation);
	void AddKey(float target_time, const Property& property, Element& element);
	bool IsValid(Element& element);
	void Update(Element& element, PropertyId id, float delta);
protected:
	void UpdateProperty(Element& element, PropertyId id, float time);
private:
	std::vector<AnimationKey> keys;
	int num_iterations;       // -1 for infinity
	int current_iteration;
	bool alternate_direction; // between iterations
	bool reverse_direction;
};

}
