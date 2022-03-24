#pragma once

#include <stdint.h>

namespace Rml {

enum class PropertyUnit : uint8_t {
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
	TRANSFORM,        // transform; fetch as < Transform >, may be empty
	TRANSITION,       // transition; fetch as < TransitionList >
	ANIMATION,        // animation; fetch as < AnimationList >
};

struct PropertyFloatValue {
	PropertyFloatValue() noexcept : value(0.f), unit(PropertyUnit::UNKNOWN) {}
	PropertyFloatValue(float v, PropertyUnit unit) : value(v), unit(unit) {}
	float value;
	PropertyUnit unit;
};

inline bool operator==(const PropertyFloatValue& l, const PropertyFloatValue& r) {
	return (l.unit == r.unit) && (l.value == r.value);
}

}
