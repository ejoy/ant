#pragma once

#include <css/Property.h>
#include <core/Tween.h>
#include <core/ID.h>

namespace Rml {

struct Keyframe;

class ElementTransition {
public:
	ElementTransition(const Property& in_prop, const Property& out_prop, const Transition& transition);
	void Update(Element& element, PropertyId id, float delta);
	bool IsComplete() const { return animation_complete; }
	bool IsValid(Element& element);
	float GetTime() const { return time; }
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

class ElementAnimation {
public:
	ElementAnimation(const Animation& animation, const Keyframe& keyframe);
	void Update(Element& element, PropertyId id, float delta);
	const std::string& GetName() const { return animation.name; }
	bool IsComplete() const { return animation_complete; }
	float GetTime() const { return time; }
protected:
	void UpdateProperty(Element& element, PropertyId id, float time);
private:
	const Animation& animation;
	const Keyframe& keyframe;
	float time;
	int current_iteration;
	bool animation_complete;
	bool reverse_direction;
};

}
