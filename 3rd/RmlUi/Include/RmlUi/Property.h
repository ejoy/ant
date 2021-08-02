/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2008-2010 CodePoint Ltd, Shift Technology Ltd
 * Copyright (c) 2019 The RmlUi Team, and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#ifndef RMLUI_CORE_PROPERTY_H
#define RMLUI_CORE_PROPERTY_H

#include "Header.h"
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

/**
	@author Peter Curry
 */

class Property {
public:
	enum Unit
	{
		UNKNOWN = 1 << 0,

		KEYWORD = 1 << 1,           // generic keyword; fetch as < int >

		STRING = 1 << 2,            // generic string; fetch as < std::string >

		// Absolute values.
		NUMBER = 1 << 3,            // number unsuffixed; fetch as < float >
		PX = 1 << 4,                // number suffixed by 'px'; fetch as < float >
		DEG = 1 << 5,               // number suffixed by 'deg'; fetch as < float >
		RAD = 1 << 6,               // number suffixed by 'rad'; fetch as < float >
		COLOUR = 1 << 7,            // colour; fetch as < Color >
		DP = 1 << 8,                // density-independent pixel; number suffixed by 'dp'; fetch as < float >
		ABSOLUTE_UNIT = NUMBER | PX | DP | DEG | RAD | COLOUR,

		// Relative values.
		EM = 1 << 9,                // number suffixed by 'em'; fetch as < float >
		PERCENT = 1 << 10,          // number suffixed by '%'; fetch as < float >
		REM = 1 << 11,              // number suffixed by 'rem'; fetch as < float >
		RELATIVE_UNIT = EM | REM | PERCENT,

		// Values based on pixels-per-inch.
		INCH = 1 << 12,             // number suffixed by 'in'; fetch as < float >
		CM = 1 << 13,               // number suffixed by 'cm'; fetch as < float >
		MM = 1 << 14,               // number suffixed by 'mm'; fetch as < float >
		PT = 1 << 15,               // number suffixed by 'pt'; fetch as < float >
		PC = 1 << 16,               // number suffixed by 'pc'; fetch as < float >
		PPI_UNIT = INCH | CM | MM | PT | PC,

		TRANSFORM = 1 << 17,        // transform; fetch as < TransformPtr >, may be empty
		TRANSITION = 1 << 18,       // transition; fetch as < TransitionList >
		ANIMATION = 1 << 19,        // animation; fetch as < AnimationList >

		LENGTH = PX | DP | PPI_UNIT | EM | REM,
		LENGTH_PERCENT = LENGTH | PERCENT,
		NUMBER_LENGTH_PERCENT = NUMBER | LENGTH | PERCENT,
		ABSOLUTE_LENGTH = PX | DP | PPI_UNIT,
		ANGLE = DEG | RAD
	};

	Property();

	template < typename PropertyType >
	Property(PropertyType value, Unit unit, int specificity = -1)
		: value(value)
		, unit(unit)
		, specificity(specificity)
	{}

	/// Get the value of the property as a string.
	std::string ToString() const;

	FloatValue ToFloatValue() const;

	template <typename T>
	T const& Get() const { return std::get<T>(value); }
	template <typename T>
	T& Get() { return std::get<T>(value); }
	template <typename T>
	bool Has() const { return std::holds_alternative<T>(value); }


	bool operator==(const Property& other) const { return unit == other.unit && value == other.value; }
	bool operator!=(const Property& other) const { return !(*this == other); }

	PropertyVariant value;
	Unit unit;
	int specificity;
	const PropertyDefinition* definition = nullptr;
};

struct FloatValue {
	FloatValue() noexcept : value(0.f), unit(Property::UNKNOWN) {}
	FloatValue(float v, Property::Unit unit) : value(v), unit(unit) {}
	float value;
	Property::Unit unit;
};

} // namespace Rml
#endif
