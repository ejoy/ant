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

	Property    Interpolate(const Property& other, float alpha) const;
	bool        AllowInterpolate(Element& e) const;

	template <typename T>
	T& GetRef() {
		assert(Has<T>());
		return std::get<T>(*this);
	}

	const PropertyFloat& GetPropertyFloat() const {
		assert(Has<PropertyFloat>());
		return std::get<PropertyFloat>(*this);
	}

	template <typename T>
	bool Has() const { return std::holds_alternative<T>(*this); }
};

template <typename T>
T InterpolateFallback(const T& p0, const T& p1, float alpha) { return alpha < 1.f ? p0 : p1; }

}
