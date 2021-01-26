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

#include "ElementAnimation.h"
#include "ElementStyle.h"
#include "../Include/RmlUi/Math.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/PropertyDefinition.h"
#include "../Include/RmlUi/StyleSheetSpecification.h"
#include "../Include/RmlUi/Transform.h"

namespace Rml {

static Property InterpolateProperties(const Property& p0, const Property& p1, float alpha, Element& element)
{
	if ((p0.unit & Property::NUMBER_LENGTH_PERCENT) && (p1.unit & Property::NUMBER_LENGTH_PERCENT))
	{
		assert(p0.unit == p1.unit);
		// If we have the same units, we can just interpolate regardless of what the value represents.
		// Or if we have distinct units but no definition, all bets are off. This shouldn't occur, just interpolate values.
		float f0 = p0.value.Get<float>();
		float f1 = p1.value.Get<float>();
		float f = (1.0f - alpha) * f0 + alpha * f1;
		return Property{ f, p0.unit };
	}

	if (p0.unit == Property::COLOUR && p1.unit == Property::COLOUR)
	{
		Color c0 = p0.value.Get<Color>();
		Color c1 = p1.value.Get<Color>();
		return Property{ ColorInterpolate(c0, c1, alpha), Property::COLOUR };
	}

	if (p0.unit == Property::TRANSFORM && p1.unit == Property::TRANSFORM)
	{
		auto& t0 = p0.value.GetReference<TransformPtr>();
		auto& t1 = p1.value.GetReference<TransformPtr>();
		auto t = t0->Interpolate(*t1, alpha);
		if (!t) {
			RMLUI_ERRORMSG("Transform primitives can not be interpolated.");
			return Property{ t0, Property::TRANSFORM };
		}
		return Property{ TransformPtr(std::move(t)), Property::TRANSFORM };
	}

	// Fall back to discrete interpolation for incompatible units.
	return alpha < 0.5f ? p0 : p1;
}

//
// see
//   https://www.w3.org/TR/css-transforms-1/#interpolation-of-transforms
//   https://www.w3.org/TR/css-transforms-2/#interpolation-of-transform-functions
//
static bool PrepareTransformPair(Transform& t0, Transform& t1, Element& element) {
	for (auto& p0 : t0) {
		if (!p0.PrepareForInterpolation(element)) {
			return false;
		}
	}
	for (auto& p1 : t1) {
		if (!p1.PrepareForInterpolation(element)) {
			return false;
		}
	}

	if (t0.size() != t1.size()) {
		bool t0_shorter = t0.size() < t1.size();
		auto& shorter = t0_shorter ? t0 : t1;
		auto& longer = t0_shorter ? t1 : t0;
		size_t i = 0;
		for (; i < shorter.size(); ++i) {
			auto& p0 = shorter[i];
			auto& p1 = longer[i];
			if (p0.index() == p1.index()) {
				continue;
			}
			if (p0.GetType() == p1.GetType()) {
				p0.ConvertToGenericType();
				p1.ConvertToGenericType();
				RMLUI_ASSERT(p0.index() == p1.index());
				continue;
			}
			if (shorter.size() < longer.size()) {
				TransformPrimitive p = p1;
				p.SetIdentity();
				shorter.insert(shorter.begin() + i, p);
				continue;
			}
			return t0.Combine(element, i) && t1.Combine(element, i);
		}
		for (; i < longer.size(); ++i) {
			auto& p1 = longer[i];
			TransformPrimitive p = p1;
			p.SetIdentity();
			shorter.insert(shorter.begin() + i, p);
		}
		return true;
	}

	RMLUI_ASSERT(t0.size() == t1.size());
	for (size_t i = 0; i < t0.size(); ++i) {
		if (t0[i].index() != t1[i].index()) {
			return t0.Combine(element, i) && t1.Combine(element, i);
		}
	}
	return true;
}


static bool PrepareTransforms(Property& property, Element& element) {
	RMLUI_ASSERT(property.value.GetType() == Variant::TRANSFORMPTR);
	if (!property.value.GetReference<TransformPtr>()) {
		property.value = MakeShared<Transform>();
	}
	return true;
}

static bool PrepareTransforms(AnimationKey& key, Element& element) {
	auto& prop0 = key.in;
	auto& prop1 = key.out;
	if (prop0.unit != Property::TRANSFORM || prop1.unit != Property::TRANSFORM) {
		return false;
	}
	if (!prop0.value.GetReference<TransformPtr>()) {
		prop0.value = MakeShared<Transform>();
	}
	if (!prop1.value.GetReference<TransformPtr>()) {
		prop1.value = MakeShared<Transform>();
	}
	auto& t0 = prop0.value.GetReference<TransformPtr>();
	auto& t1 = prop1.value.GetReference<TransformPtr>();
	return PrepareTransformPair(*t0, *t1, element);
}

ElementAnimation::ElementAnimation(PropertyId property_id, ElementAnimationOrigin origin, const Property& current_value, Element& element, double start_world_time, float duration, int num_iterations, bool alternate_direction)
	: property_id(property_id)
	, duration(duration)
	, num_iterations(num_iterations)
	, alternate_direction(alternate_direction)
	, last_update_world_time(start_world_time)
	, time_since_iteration_start(0.0f)
	, current_iteration(0)
	, reverse_direction(false)
	, animation_complete(false)
	, origin(origin)
{
	if (!current_value.definition) {
		Log::Message(Log::LT_WARNING, "Property in animation key did not have a definition (while adding key '%s').", current_value.ToString().c_str());
	}
	InternalAddKey(0.0f, current_value, element, Tween{});
}


bool ElementAnimation::InternalAddKey(float time, const Property& out_prop, Element& element, Tween tween)
{
	if (!(out_prop.unit & (Property::NUMBER_LENGTH_PERCENT | Property::ANGLE | Property::COLOUR | Property::TRANSFORM | Property::KEYWORD))) {
		Log::Message(Log::LT_WARNING, "Property '%s' is not a valid target for interpolation.", out_prop.ToString().c_str());
		return false;
	}

	bool first = keys.size() == 0;
	Property const& in_prop = first ? out_prop: keys.back().prop;
	keys.emplace_back(time, in_prop, out_prop, tween);
	bool result = true;
	if (!first && out_prop.unit == Property::TRANSFORM) {
		result = PrepareTransforms(keys.back(), element);
	}
	if (!result) {
		Log::Message(Log::LT_WARNING, "Could not add animation key with property '%s'.", out_prop.ToString().c_str());
		keys.pop_back();
	}
	return result;
}


bool ElementAnimation::AddKey(float target_time, const Property & in_property, Element& element, Tween tween, bool remove) {
	if (!IsInitalized()) {
		Log::Message(Log::LT_WARNING, "Element animation was not initialized properly, can't add key.");
		return false;
	}
	if (!InternalAddKey(target_time, in_property, element, tween)) {
		return false;
	}
	duration = target_time;
	remove_when_complete = remove;
	return true;
}

float ElementAnimation::GetInterpolationFactorAndKeys(int* out_key) const
{
	float t = time_since_iteration_start;

	if (reverse_direction)
		t = duration - t;

	int key0 = -1;
	int key1 = -1;

	{
		for (int i = 0; i < (int)keys.size(); i++)
		{
			if (keys[i].time >= t)
			{
				key1 = i;
				break;
			}
		}

		if (key1 < 0) key1 = (int)keys.size() - 1;
		key0 = (key1 == 0 ? 0 : key1 - 1);
	}

	RMLUI_ASSERT(key0 >= 0 && key0 < (int)keys.size() && key1 >= 0 && key1 < (int)keys.size());

	float alpha = 0.0f;

	{
		const float t0 = keys[key0].time;
		const float t1 = keys[key1].time;

		const float eps = 1e-3f;

		if (t1 - t0 > eps)
			alpha = (t - t0) / (t1 - t0);

		alpha = Math::Clamp(alpha, 0.0f, 1.0f);
	}

	alpha = keys[key1].tween(alpha);

	if (out_key) *out_key = key1;
	return alpha;
}

Property ElementAnimation::UpdateAndGetProperty(double world_time, Element& element)
{
	float dt = float(world_time - last_update_world_time);
	if (keys.size() < 2 || animation_complete || dt <= 0.0f)
		return Property{};

	dt = Math::Min(dt, 0.1f);

	last_update_world_time = world_time;
	time_since_iteration_start += dt;

	if (time_since_iteration_start >= duration)
	{
		// Next iteration
		current_iteration += 1;

		if (num_iterations == -1 || (current_iteration >= 0 && current_iteration < num_iterations))
		{
			time_since_iteration_start -= duration;

			if (alternate_direction)
				reverse_direction = !reverse_direction;
		}
		else
		{
			animation_complete = true;
			time_since_iteration_start = duration;
		}
	}

	int key = -1;
	float alpha = GetInterpolationFactorAndKeys(&key);
	return InterpolateProperties(keys[key].in, keys[key].out, alpha, element);
}

void ElementAnimation::Release(Element& element) {
	if (!IsInitalized()) {
		return;
	}
	switch (GetOrigin()) {
	case ElementAnimationOrigin::User:
		break;
	case ElementAnimationOrigin::Animation:
	case ElementAnimationOrigin::Transition:
		if (remove_when_complete) {
			element.RemoveProperty(GetPropertyId());
		}
		else {
			element.SetProperty(GetPropertyId(), keys.back().prop);
		}
		break;
	}
}

} // namespace Rml
