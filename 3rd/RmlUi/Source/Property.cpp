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

constexpr float UndefinedFloat = std::numeric_limits<float>::quiet_NaN();

Property::Property() : unit(UNKNOWN), specificity(-1)
{
	definition = nullptr;
}

std::string Property::ToString() const {
	switch (unit) {
	case Property::STRING:
		return std::get<std::string>(value);
	case Property::KEYWORD: {
		int keyword = std::get<int>(value);
		return "<keyword," + std::to_string(keyword) + ">";
	}
	case Property::COLOUR: {
		Color colour = std::get<Color>(value);
		return CreateString(32, "rgba(%d,%d,%d,%d)", colour.r, colour.g, colour.b, colour.a);
	}
	case Property::TRANSFORM:
		return "<transform>";
	case Property::TRANSITION:
		return "<transition>";
	case Property::ANIMATION:
		return "<animation>";
	case Property::NUMBER:	return std::to_string(std::get<float>(value));
	case Property::PX:		return std::to_string(std::get<float>(value)) + "px";
	case Property::DEG:		return std::to_string(std::get<float>(value)) + "deg";
	case Property::RAD:		return std::to_string(std::get<float>(value)) + "rad";
	case Property::EM:		return std::to_string(std::get<float>(value)) + "em";
	case Property::REM:		return std::to_string(std::get<float>(value)) + "rem";
	case Property::PERCENT:	return std::to_string(std::get<float>(value)) + "%";
	case Property::INCH:	return std::to_string(std::get<float>(value)) + "in";
	case Property::CM:		return std::to_string(std::get<float>(value)) + "cm";
	case Property::MM:		return std::to_string(std::get<float>(value)) + "mm";
	case Property::PT:		return std::to_string(std::get<float>(value)) + "pt";
	case Property::PC:		return std::to_string(std::get<float>(value)) + "pc";
	case Property::VW:		return std::to_string(std::get<float>(value)) + "vw";
	case Property::VH:		return std::to_string(std::get<float>(value)) + "vh";
	case Property::VMIN:		return std::to_string(std::get<float>(value)) + "vmin";
	case Property::VMAX:		return std::to_string(std::get<float>(value)) + "vmax";
	default:
		return "<unknown, " + std::to_string(unit) + ">";
	}
}

float Property::GetFloat() const {
	switch (unit) {
	case Property::NUMBER:
	case Property::PX:
	case Property::DEG:
	case Property::RAD:
	case Property::EM:
	case Property::REM:
	case Property::PERCENT:
	case Property::INCH:
	case Property::CM:
	case Property::MM:
	case Property::PT:
	case Property::PC:
	case Property::VW:
	case Property::VH:
	case Property::VMIN:
	case Property::VMAX:
		return std::get<float>(value);
	default:
		return UndefinedFloat;
	}
}

Color Property::GetColor() const {
	switch (unit) {
	case Property::COLOUR:
		return std::get<Color>(value);
	default:
		return Color{};
	}
}

int Property::GetKeyword() const {
	switch (unit) {
	case Property::KEYWORD:
		return std::get<int>(value);
	default:
		return 0;
	}
}

std::string Property::GetString() const {
	switch (unit) {
	case Property::STRING:
		return std::get<std::string>(value);
	default:
		return "";
	}
}

TransformPtr& Property::GetTransformPtr() {
	switch (unit) {
	case Property::TRANSFORM:
		return std::get<TransformPtr>(value);
	default: {
		static TransformPtr dummy {};
		return dummy;
	}
	}
}

TransitionList& Property::GetTransitionList() {
	switch (unit) {
	case Property::TRANSITION:
		return std::get<TransitionList>(value);
	default: {
		static TransitionList dummy {};
		return dummy;
	}
	}
}

AnimationList& Property::GetAnimationList() {
	switch (unit) {
	case Property::ANIMATION:
		return std::get<AnimationList>(value);
	default: {
		static AnimationList dummy {};
		return dummy;
	}
	}
}

TransformPtr const& Property::GetTransformPtr() const {
	switch (unit) {
	case Property::TRANSFORM:
		return std::get<TransformPtr>(value);
	default: {
		static TransformPtr dummy {};
		return dummy;
	}
	}
}

TransitionList const& Property::GetTransitionList() const {
	switch (unit) {
	case Property::TRANSITION:
		return std::get<TransitionList>(value);
	default: {
		static TransitionList dummy {};
		return dummy;
	}
	}
}

AnimationList const& Property::GetAnimationList() const {
	switch (unit) {
	case Property::ANIMATION:
		return std::get<AnimationList>(value);
	default: {
		static AnimationList dummy {};
		return dummy;
	}
	}
}

FloatValue Property::ToFloatValue() const {
	if (unit & Property::KEYWORD) {
		switch (std::get<int>(value)) {
		default:
		case 0 /* left/top     */: return { 0.0f, Property::Unit::PERCENT }; break;
		case 1 /* center       */: return { 50.0f, Property::Unit::PERCENT }; break;
		case 2 /* right/bottom */: return { 100.0f, Property::Unit::PERCENT }; break;
		}
	}
	float v = GetFloat();
	if (v == UndefinedFloat) {
		return { v, Property::UNKNOWN };
	}
	return { v, unit };
}

template <>
std::string ToString<FloatValue>(const FloatValue& v) {
	std::string value = std::to_string(v.value);
	switch (v.unit) {
		case Property::PX:		value += "px"; break;
		case Property::DEG:		value += "deg"; break;
		case Property::RAD:		value += "rad"; break;
		case Property::EM:		value += "em"; break;
		case Property::REM:		value += "rem"; break;
		case Property::PERCENT:	value += "%"; break;
		case Property::INCH:	value += "in"; break;
		case Property::CM:		value += "cm"; break;
		case Property::MM:		value += "mm"; break;
		case Property::PT:		value += "pt"; break;
		case Property::PC:		value += "pc"; break;
		case Property::VW:		value += "vw"; break;
		case Property::VH:		value += "vh"; break;
		case Property::VMIN:	value += "vmin"; break;
		case Property::VMAX:	value += "vmax"; break;
		default:				break;
	}
	return value;
}

} // namespace Rml
