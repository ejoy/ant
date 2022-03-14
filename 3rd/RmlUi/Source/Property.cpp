#include "../Include/RmlUi/Property.h"
#include "../Include/RmlUi/PropertyDefinition.h"
#include "../Include/RmlUi/StringUtilities.h"

namespace Rml {

constexpr float UndefinedFloat = std::numeric_limits<float>::quiet_NaN();

Property::Property() : unit(Unit::UNKNOWN)
{ }

std::string Property::ToString() const {
	switch (unit) {
	case Property::Unit::STRING:
		return std::get<std::string>(value);
	case Property::Unit::KEYWORD: {
		int keyword = std::get<int>(value);
		return "<keyword," + std::to_string(keyword) + ">";
	}
	case Property::Unit::COLOUR: {
		auto sRGB = std::get<Color>(value).toSRGB();
		return CreateString(32, "rgba(%d,%d,%d,%d)", sRGB.r, sRGB.g, sRGB.b, sRGB.a);
	}
	case Property::Unit::TRANSFORM:
		return "<transform>";
	case Property::Unit::TRANSITION:
		return "<transition>";
	case Property::Unit::ANIMATION:
		return "<animation>";
	case Property::Unit::NUMBER:	return std::to_string(std::get<float>(value));
	case Property::Unit::PX:		return std::to_string(std::get<float>(value)) + "px";
	case Property::Unit::DEG:		return std::to_string(std::get<float>(value)) + "deg";
	case Property::Unit::RAD:		return std::to_string(std::get<float>(value)) + "rad";
	case Property::Unit::EM:		return std::to_string(std::get<float>(value)) + "em";
	case Property::Unit::REM:		return std::to_string(std::get<float>(value)) + "rem";
	case Property::Unit::PERCENT:	return std::to_string(std::get<float>(value)) + "%";
	case Property::Unit::INCH:	return std::to_string(std::get<float>(value)) + "in";
	case Property::Unit::CM:		return std::to_string(std::get<float>(value)) + "cm";
	case Property::Unit::MM:		return std::to_string(std::get<float>(value)) + "mm";
	case Property::Unit::PT:		return std::to_string(std::get<float>(value)) + "pt";
	case Property::Unit::PC:		return std::to_string(std::get<float>(value)) + "pc";
	case Property::Unit::VW:		return std::to_string(std::get<float>(value)) + "vw";
	case Property::Unit::VH:		return std::to_string(std::get<float>(value)) + "vh";
	case Property::Unit::VMIN:		return std::to_string(std::get<float>(value)) + "vmin";
	case Property::Unit::VMAX:		return std::to_string(std::get<float>(value)) + "vmax";
	default:
		return "<unknown, " + std::to_string((uint32_t)unit) + ">";
	}
}

float Property::GetFloat() const {
	switch (unit) {
	case Property::Unit::NUMBER:
	case Property::Unit::PX:
	case Property::Unit::DEG:
	case Property::Unit::RAD:
	case Property::Unit::EM:
	case Property::Unit::REM:
	case Property::Unit::PERCENT:
	case Property::Unit::INCH:
	case Property::Unit::CM:
	case Property::Unit::MM:
	case Property::Unit::PT:
	case Property::Unit::PC:
	case Property::Unit::VW:
	case Property::Unit::VH:
	case Property::Unit::VMIN:
	case Property::Unit::VMAX:
		return std::get<float>(value);
	default:
		return UndefinedFloat;
	}
}

Color Property::GetColor() const {
	switch (unit) {
	case Property::Unit::COLOUR:
		return std::get<Color>(value);
	default:
		return Color{};
	}
}

int Property::GetKeyword() const {
	switch (unit) {
	case Property::Unit::KEYWORD:
		return std::get<int>(value);
	default:
		return 0;
	}
}

std::string Property::GetString() const {
	switch (unit) {
	case Property::Unit::STRING:
		return std::get<std::string>(value);
	default:
		return "";
	}
}

TransformPtr& Property::GetTransformPtr() {
	switch (unit) {
	case Property::Unit::TRANSFORM:
		return std::get<TransformPtr>(value);
	default: {
		static TransformPtr dummy {};
		return dummy;
	}
	}
}

TransitionList& Property::GetTransitionList() {
	switch (unit) {
	case Property::Unit::TRANSITION:
		return std::get<TransitionList>(value);
	default: {
		static TransitionList dummy {};
		return dummy;
	}
	}
}

AnimationList& Property::GetAnimationList() {
	switch (unit) {
	case Property::Unit::ANIMATION:
		return std::get<AnimationList>(value);
	default: {
		static AnimationList dummy {};
		return dummy;
	}
	}
}

TransformPtr const& Property::GetTransformPtr() const {
	switch (unit) {
	case Property::Unit::TRANSFORM:
		return std::get<TransformPtr>(value);
	default: {
		static TransformPtr dummy {};
		return dummy;
	}
	}
}

TransitionList const& Property::GetTransitionList() const {
	switch (unit) {
	case Property::Unit::TRANSITION:
		return std::get<TransitionList>(value);
	default: {
		static TransitionList dummy {};
		return dummy;
	}
	}
}

AnimationList const& Property::GetAnimationList() const {
	switch (unit) {
	case Property::Unit::ANIMATION:
		return std::get<AnimationList>(value);
	default: {
		static AnimationList dummy {};
		return dummy;
	}
	}
}

FloatValue Property::ToFloatValue() const {
	if (unit == Property::Unit::KEYWORD) {
		switch (std::get<int>(value)) {
		default:
		case 0 /* left/top     */: return { 0.0f, Property::Unit::PERCENT }; break;
		case 1 /* center       */: return { 50.0f, Property::Unit::PERCENT }; break;
		case 2 /* right/bottom */: return { 100.0f, Property::Unit::PERCENT }; break;
		}
	}
	float v = GetFloat();
	if (v == UndefinedFloat) {
		return { v, Property::Unit::UNKNOWN };
	}
	return { v, unit };
}

template <>
std::string ToString<FloatValue>(const FloatValue& v) {
	std::string value = std::to_string(v.value);
	switch (v.unit) {
		case Property::Unit::PX:		value += "px"; break;
		case Property::Unit::DEG:		value += "deg"; break;
		case Property::Unit::RAD:		value += "rad"; break;
		case Property::Unit::EM:		value += "em"; break;
		case Property::Unit::REM:		value += "rem"; break;
		case Property::Unit::PERCENT:	value += "%"; break;
		case Property::Unit::INCH:		value += "in"; break;
		case Property::Unit::CM:		value += "cm"; break;
		case Property::Unit::MM:		value += "mm"; break;
		case Property::Unit::PT:		value += "pt"; break;
		case Property::Unit::PC:		value += "pc"; break;
		case Property::Unit::VW:		value += "vw"; break;
		case Property::Unit::VH:		value += "vh"; break;
		case Property::Unit::VMIN:		value += "vmin"; break;
		case Property::Unit::VMAX:		value += "vmax"; break;
		default:				break;
	}
	return value;
}

}
