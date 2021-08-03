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

#include "../Include/RmlUi/Property.h"
#include "../Include/RmlUi/PropertyDefinition.h"
#include "../Include/RmlUi/StringUtilities.h"

namespace Rml {

Property::Property() : unit(UNKNOWN), specificity(-1)
{
	definition = nullptr;
}

std::string Property::ToString() const {
	std::string value = Get<std::string>();
	switch (unit) {
	case Property::STRING:
		return Get<std::string>();
	case Property::KEYWORD: {
		int keyword = Get<int>();
		return "<keyword," + std::to_string(keyword) + ">";
	}
	case Property::COLOUR: {
		Color colour = Get<Color>();
		return CreateString(32, "rgba(%d,%d,%d,%d)", colour.r, colour.g, colour.b, colour.a);
	}
	case Property::TRANSFORM:
		return "<transform>";
	case Property::TRANSITION:
		return "<transition>";
	case Property::ANIMATION:
		return "<animation>";
	case Property::NUMBER:	return std::to_string(Get<float>());
	case Property::PX:		return std::to_string(Get<float>()) + "px";
	case Property::DEG:		return std::to_string(Get<float>()) + "deg";
	case Property::RAD:		return std::to_string(Get<float>()) + "rad";
	case Property::DP:		return std::to_string(Get<float>()) + "dp";
	case Property::EM:		return std::to_string(Get<float>()) + "em";
	case Property::REM:		return std::to_string(Get<float>()) + "rem";
	case Property::PERCENT:	return std::to_string(Get<float>()) + "%";
	case Property::INCH:	return std::to_string(Get<float>()) + "in";
	case Property::CM:		return std::to_string(Get<float>()) + "cm";
	case Property::MM:		return std::to_string(Get<float>()) + "mm";
	case Property::PT:		return std::to_string(Get<float>()) + "pt";
	case Property::PC:		return std::to_string(Get<float>()) + "pc";
	default:
		return "<unknown, " + std::to_string(unit) + ">";
	}
}

FloatValue Property::ToFloatValue() const {
	if (unit & Property::KEYWORD) {
		switch (Get<int>()) {
		default:
		case 0 /* left/top     */: return { 0.0f, Property::Unit::PERCENT }; break;
		case 1 /* center       */: return { 50.0f, Property::Unit::PERCENT }; break;
		case 2 /* right/bottom */: return { 100.0f, Property::Unit::PERCENT }; break;
		}
	}
	return {
		Get<float>(),
		unit,
	};
}

template <>
std::string ToString<FloatValue>(const FloatValue& v) {
	std::string value = std::to_string(v.value);
	switch (v.unit) {
		case Property::PX:		value += "px"; break;
		case Property::DEG:		value += "deg"; break;
		case Property::RAD:		value += "rad"; break;
		case Property::DP:		value += "dp"; break;
		case Property::EM:		value += "em"; break;
		case Property::REM:		value += "rem"; break;
		case Property::PERCENT:	value += "%"; break;
		case Property::INCH:	value += "in"; break;
		case Property::CM:		value += "cm"; break;
		case Property::MM:		value += "mm"; break;
		case Property::PT:		value += "pt"; break;
		case Property::PC:		value += "pc"; break;
		default:					break;
	}
	return value;
}

} // namespace Rml
