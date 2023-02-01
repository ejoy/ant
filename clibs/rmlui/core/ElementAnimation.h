#pragma once

#include <core/Property.h>
#include <core/Tween.h>
#include <core/ID.h>


namespace Rml {

struct AnimationKey {
	AnimationKey(float time, const Property& in_prop, const Property& out_prop, Tween tween)
		: time(time)
		, in(in_prop)
		, out(out_prop)
		, prop(out_prop)
		, tween(tween)
	{}
	float time;   // Local animation time (Zero means the time when the animation iteration starts)
	Property in;
	Property out;
	Property prop;
	Tween tween;  // Tweening between the previous and this key. Ignored for the first animation key.
};

// The origin is tracked for determining its behavior when adding and removing animations.
// Animation: Animation started by the 'animation' property
// Transition: Animation started by the 'transition' property
enum class ElementAnimationOrigin : uint8_t { Animation, Transition };

class ElementAnimation {
public:
	ElementAnimation(PropertyId property_id, ElementAnimationOrigin origin, float start_time, int num_iterations, bool alternate_direction);
	bool AddKey(float target_time, const Property & property, Element & element, Tween tween);
	void Update(Element& element, float delta);
	PropertyId GetPropertyId() const { return property_id; }
	bool IsComplete() const { return animation_complete; }
	bool IsTransition() const { return origin == ElementAnimationOrigin::Transition; }
	bool IsInitalized() const { return !keys.empty(); }
	void Release(Element& element);
private:
	float GetInterpolationFactorAndKeys(int* out_key) const;
private:
	PropertyId property_id;
	float duration;           // for a single iteration
	int num_iterations;       // -1 for infinity
	bool alternate_direction; // between iterations
	std::vector<AnimationKey> keys;
	float time;
	int current_iteration;
	bool reverse_direction;
	bool animation_complete;
	ElementAnimationOrigin origin;
};

}
