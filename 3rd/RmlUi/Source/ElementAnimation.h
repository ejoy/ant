/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2018 Michael R. P. Ragazzon
 * Copyright (c) 2019 The RmlUi Team, and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#ifndef RMLUI_CORE_ELEMENTANIMATION_H
#define RMLUI_CORE_ELEMENTANIMATION_H

#include "../Include/RmlUi/Property.h"
#include "../Include/RmlUi/Tween.h"
#include "../Include/RmlUi/ID.h"


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
// User: Animation started by the Element API
// Animation: Animation started by the 'animation' property
// Transition: Animation started by the 'transition' property
enum class ElementAnimationOrigin : uint8_t { User, Animation, Transition };

class ElementAnimation
{
private:
	PropertyId property_id = PropertyId::Invalid;
	float duration = 0;           // for a single iteration
	int num_iterations = 0;       // -1 for infinity
	bool alternate_direction = 0; // between iterations
	std::vector<AnimationKey> keys;
	double last_update_world_time = 0;
	float time_since_iteration_start = 0;
	int current_iteration = 0;
	bool reverse_direction = false;
	bool animation_complete = true;
	ElementAnimationOrigin origin = ElementAnimationOrigin::User;

	bool InternalAddKey(float time, const Property& out_prop, Element& element, Tween tween);
	float GetInterpolationFactorAndKeys(int* out_key) const;

public:
	ElementAnimation(PropertyId property_id, ElementAnimationOrigin origin, const Property& current_value, Element& element,
		double start_world_time, float duration, int num_iterations, bool alternate_direction);

	bool AddKey(float target_time, const Property & property, Element & element, Tween tween);

	Property UpdateAndGetProperty(double time, Element& element);

	PropertyId GetPropertyId() const { return property_id; }
	float GetDuration() const { return duration; }
	bool IsComplete() const { return animation_complete; }
	bool IsTransition() const { return origin == ElementAnimationOrigin::Transition; }
	bool IsInitalized() const { return !keys.empty(); }
	float GetInterpolationFactor() const { return GetInterpolationFactorAndKeys(nullptr); }
	ElementAnimationOrigin GetOrigin() const { return origin; }
	void Release(Element& element);
};


} // namespace Rml
#endif
