#pragma once

#include <core/Color.h>
#include <core/Animation.h>
#include <core/Transform.h>
#include <variant>
#include <string>
#include <core/PropertyFloat.h>

namespace Rml {

using PropertyKeyword = int;
using AnimationList = std::vector<Animation>;

using PropertyVariant = std::variant<
	PropertyFloat,
	PropertyKeyword,
	Color,
	std::string,
	Transform,
	Transitions,
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
	bool        AllowInterpolate() const;

	template <typename T>
	T& Get() {
		assert (Has<T>());
		return std::get<T>(*this);
	}

	template <typename T>
	const T& Get() const {
		assert (Has<T>());
		return std::get<T>(*this);
	}

	template <typename T>
	bool Has() const { return std::holds_alternative<T>(*this); }
};

template <typename T>
T InterpolateFallback(const T& p0, const T& p1, float alpha) { return alpha < 1.f ? p0 : p1; }

}
