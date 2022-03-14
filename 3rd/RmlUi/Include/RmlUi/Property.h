#pragma once

#include "Colour.h"
#include "Types.h"
#include "Animation.h"
#include <variant>
#include <string>

namespace Rml {

class PropertyDefinition;

struct FloatValue;

using PropertyVariant = std::variant<
	std::monostate,
	float,
	int,
	Color,
	std::string,
	TransformPtr,
	TransitionList,
	AnimationList
>;

class Property {
public:
	enum class Unit : uint8_t {
		UNKNOWN = 0,
		KEYWORD,          // generic keyword; fetch as < int >
		STRING,           // generic string; fetch as < std::string >
		NUMBER,           // number unsuffixed; fetch as < float >
		PX,               // number suffixed by 'px'; fetch as < float >
		DEG,              // number suffixed by 'deg'; fetch as < float >
		RAD,              // number suffixed by 'rad'; fetch as < float >
		COLOUR,           // colour; fetch as < Color >
		EM,               // number suffixed by 'em'; fetch as < float >
		PERCENT,          // number suffixed by '%'; fetch as < float >
		REM,              // number suffixed by 'rem'; fetch as < float >
		VW,
		VH,
		VMIN,
		VMAX,
		INCH,             // number suffixed by 'in'; fetch as < float >
		CM,               // number suffixed by 'cm'; fetch as < float >
		MM,               // number suffixed by 'mm'; fetch as < float >
		PT,               // number suffixed by 'pt'; fetch as < float >
		PC,               // number suffixed by 'pc'; fetch as < float >
		TRANSFORM,        // transform; fetch as < TransformPtr >, may be empty
		TRANSITION,       // transition; fetch as < TransitionList >
		ANIMATION,        // animation; fetch as < AnimationList >
	};

	template <typename T>
	static constexpr  uint32_t Mark(T p0) {
		return 1 << (uint32_t)p0;
	}

	template <typename T, typename ...Args>
	static constexpr uint32_t Mark(T p0, Args... args) {
		return Mark(p0) | Mark(args...);
	}

	enum class UnitMark : uint32_t {
		Number              = Mark(Unit::NUMBER),
		ViewLength          = Mark(Unit::VW, Unit::VH, Unit::VMIN, Unit::VMAX),
		Length              = Mark(Unit::PX, Unit::INCH, Unit::CM, Unit::MM, Unit::PT, Unit::PC, Unit::EM, Unit::REM) | (uint32_t)ViewLength,
		LengthPercent       = Mark(Unit::PERCENT) | (uint32_t)Length,
		NumberLengthPercent = Mark(Unit::NUMBER) | (uint32_t)LengthPercent,
		Angle               = Mark(Unit::DEG, Unit::RAD),
		Rem                 = Mark(Unit::REM),
	};

	static constexpr bool Contains(UnitMark mark, Unit unit) {
		return (uint32_t(mark) & Mark(unit)) != 0;
	}

	Property();

	template < typename PropertyType >
	Property(PropertyType value, Unit unit)
		: value(value)
		, unit(unit)
	{}

	std::string ToString() const;
	FloatValue ToFloatValue() const;

	float           GetFloat() const;
	Color           GetColor() const;
	int             GetKeyword() const;
	std::string     GetString() const;
	TransformPtr&   GetTransformPtr();
	TransitionList& GetTransitionList();
	AnimationList&  GetAnimationList();
	TransformPtr const&   GetTransformPtr() const;
	TransitionList const& GetTransitionList() const;
	AnimationList const&  GetAnimationList() const;

	template <typename T>
	bool Has() const { return std::holds_alternative<T>(value); }

	bool operator==(const Property& other) const { return unit == other.unit && value == other.value; }
	bool operator!=(const Property& other) const { return !(*this == other); }

	PropertyVariant value;
	Unit unit;
};

struct FloatValue {
	FloatValue() noexcept : value(0.f), unit(Property::Unit::UNKNOWN) {}
	FloatValue(float v, Property::Unit unit) : value(v), unit(unit) {}
	float value;
	Property::Unit unit;
};

}
