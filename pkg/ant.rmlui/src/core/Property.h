#pragma once

#include <core/Color.h>
#include <core/Animation.h>
#include <core/Transform.h>
#include <variant>
#include <string>
#include <core/PropertyFloat.h>

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

}
