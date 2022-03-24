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
	template <typename T>
	static constexpr  uint32_t Mark(T p0) {
		return 1 << (uint32_t)p0;
	}

	template <typename T, typename ...Args>
	static constexpr uint32_t Mark(T p0, Args... args) {
		return Mark(p0) | Mark(args...);
	}

	enum class UnitMark : uint32_t {
		Number              = Mark(PropertyUnit::NUMBER),
		ViewLength          = Mark(PropertyUnit::VW, PropertyUnit::VH, PropertyUnit::VMIN, PropertyUnit::VMAX),
		Length              = Mark(PropertyUnit::PX, PropertyUnit::INCH, PropertyUnit::CM, PropertyUnit::MM, PropertyUnit::PT, PropertyUnit::PC, PropertyUnit::EM, PropertyUnit::REM) | (uint32_t)ViewLength,
		LengthPercent       = Mark(PropertyUnit::PERCENT) | (uint32_t)Length,
		NumberLengthPercent = Mark(PropertyUnit::NUMBER) | (uint32_t)LengthPercent,
		Angle               = Mark(PropertyUnit::DEG, PropertyUnit::RAD),
		Rem                 = Mark(PropertyUnit::REM),
	};

	static constexpr bool Contains(UnitMark mark, PropertyUnit unit) {
		return (uint32_t(mark) & Mark(unit)) != 0;
	}

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
