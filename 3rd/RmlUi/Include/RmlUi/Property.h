#pragma once

#include "Colour.h"
#include "Types.h"
#include "Animation.h"
#include "Transform.h"
#include <variant>
#include <string>
#include "PropertyFloatValue.h"

namespace Rml {

using PropertyVariant = std::variant<
	std::monostate,
	float,
	int,
	Color,
	std::string,
	Transform,
	TransitionList,
	AnimationList
>;

class Property {
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

	Property();

	template < typename PropertyType >
	Property(PropertyType value, PropertyUnit unit)
		: value(value)
		, unit(unit)
	{}

	std::string ToString() const;
	PropertyFloatValue ToFloatValue() const;

	float           GetFloat() const;
	Color           GetColor() const;
	int             GetKeyword() const;
	std::string     GetString() const;


	template <typename T>
	struct TypeUnit {};
	template <> struct TypeUnit<TransitionList> { static const PropertyUnit unit = PropertyUnit::TRANSITION; };
	template <> struct TypeUnit<Transform> { static const PropertyUnit unit = PropertyUnit::TRANSFORM; };
	template <> struct TypeUnit<AnimationList> { static const PropertyUnit unit = PropertyUnit::ANIMATION; };

	template <typename T>
	T& Get() {
		PropertyUnit checkunit = TypeUnit<T>::unit;
		if (checkunit == unit) {
			return std::get<T>(value);
		}
		assert(checkunit == unit);
		static T dummy {};
		return dummy;
	}

	template <typename T>
	const T& Get() const {
		PropertyUnit checkunit = TypeUnit<T>::unit;
		if (checkunit == unit) {
			return std::get<T>(value);
		}
		assert(checkunit == unit);
		static T dummy {};
		return dummy;
	}

	template <typename T>
	bool Has() const { return std::holds_alternative<T>(value); }

	bool operator==(const Property& other) const { return unit == other.unit && value == other.value; }

	PropertyVariant value;
	PropertyUnit unit;
};

}
