#pragma once

#include <core/Color.h>
#include <core/Animation.h>
#include <core/Transform.h>
#include <css/PropertyFloat.h>
#include <variant>
#include <string>

namespace Rml {

class Element;

using PropertyKeyword = int;
using AnimationList = std::vector<Animation>;

using PropertyVariant = std::variant<
	PropertyFloat,
	PropertyKeyword,
	Color,
	std::string,
	Transform,
	TransitionList,
	AnimationList
>;

class Property : public PropertyVariant {
public:
	template < typename PropertyType >
	Property(PropertyType value)
		: PropertyVariant(value)
	{}

	Property(float value, PropertyUnit unit)
		: PropertyVariant(PropertyFloat{value, unit})
	{}

	std::string ToString() const;
	Property    Interpolate(const Property& other, float alpha) const;
	bool        AllowInterpolate(Element& e) const;

	template <typename T>
	T& GetRef() {
		assert(Has<T>());
		return std::get<T>(*this);
	}

	template <typename T>
		requires (!std::is_enum_v<T> && !std::is_same_v<T, float>)
	const T& Get() const {
		assert(Has<T>());
		return std::get<T>(*this);
	}

	template <typename T>
		requires (std::is_enum_v<T>)
	T Get() const {
		assert(Has<PropertyKeyword>());
		return (T)std::get<PropertyKeyword>(*this);
	}

	template <typename T>
		requires (std::is_same_v<T, float>)
	float Get(const Element* e) const {
		assert(Has<PropertyFloat>());
		return std::get<PropertyFloat>(*this).Compute(e);
	}

	template <typename T>
	bool Has() const { return std::holds_alternative<T>(*this); }
};

template <typename T>
T InterpolateFallback(const T& p0, const T& p1, float alpha) { return alpha < 1.f ? p0 : p1; }

inline float PropertyComputeX(const Element* e, const Property& p) {
	if (p.Has<PropertyKeyword>()) {
		switch (p.Get<PropertyKeyword>()) {
		default:
		case 0 /* left   */: return PropertyFloat { 0.0f, PropertyUnit::PERCENT }.ComputeW(e);
		case 1 /* center */: return PropertyFloat { 50.0f, PropertyUnit::PERCENT }.ComputeW(e);
		case 2 /* right  */: return PropertyFloat { 100.0f, PropertyUnit::PERCENT }.ComputeW(e);
		}
	}
	return p.Get<PropertyFloat>().ComputeW(e);
}

inline float PropertyComputeY(const Element* e, const Property& p) {
	if (p.Has<PropertyKeyword>()) {
		switch (p.Get<PropertyKeyword>()) {
		default:
		case 0 /* top    */: return PropertyFloat { 0.0f, PropertyUnit::PERCENT }.ComputeH(e);
		case 1 /* center */: return PropertyFloat { 50.0f, PropertyUnit::PERCENT }.ComputeH(e);
		case 2 /* bottom */: return PropertyFloat { 100.0f, PropertyUnit::PERCENT }.ComputeH(e);
		}
	}
	return p.Get<PropertyFloat>().ComputeH(e);
}

inline float PropertyComputeZ(const Element* e, const Property& p) {
	return p.Get<PropertyFloat>().Compute(e);
}

}
