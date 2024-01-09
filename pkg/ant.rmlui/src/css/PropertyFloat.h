#pragma once

#include <stdint.h>
#include <string>

namespace Rml {

class Element;

enum class PropertyUnit : uint8_t {
	NUMBER,           // number unsuffixed; fetch as < float >
	PX,               // number suffixed by 'px'; fetch as < float >
	DEG,              // number suffixed by 'deg'; fetch as < float >
	RAD,              // number suffixed by 'rad'; fetch as < float >
	COLOUR,           // color; fetch as < Color >
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
};

struct PropertyFloat {
	PropertyFloat(float v, PropertyUnit unit);
	std::string ToString() const;
	float Compute(const Element* e) const;
	float ComputeW(const Element* e) const;
	float ComputeH(const Element* e) const;
	float ComputeAngle() const;
	PropertyFloat Interpolate(const PropertyFloat& p1, float alpha) const;

	float value;
	PropertyUnit unit;
};

}
