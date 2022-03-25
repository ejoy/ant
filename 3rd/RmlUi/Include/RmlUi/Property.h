#pragma once

#include "Colour.h"
#include "Types.h"
#include "Animation.h"
#include "Transform.h"
#include <variant>
#include <string>
#include "PropertyFloat.h"

namespace Rml {

using PropertyKeyword = int;

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

}
