#include "../Include/RmlUi/Property.h"
#include "../Include/RmlUi/PropertyDefinition.h"
#include "../Include/RmlUi/StringUtilities.h"

namespace Rml {

constexpr float UndefinedFloat = std::numeric_limits<float>::quiet_NaN();

Property::Property() : unit(PropertyUnit::UNKNOWN)
{ }

std::string Property::ToString() const {
	switch (unit) {
	case PropertyUnit::STRING:
		return std::get<std::string>(value);
	case PropertyUnit::KEYWORD: {
		int keyword = std::get<int>(value);
		return "<keyword," + std::to_string(keyword) + ">";
	}
	case PropertyUnit::COLOUR: {
		auto sRGB = std::get<Color>(value).toSRGB();
		return CreateString(32, "rgba(%d,%d,%d,%d)", sRGB.r, sRGB.g, sRGB.b, sRGB.a);
	}
	case PropertyUnit::TRANSFORM:
		return "<transform>";
	case PropertyUnit::TRANSITION:
		return "<transition>";
	case PropertyUnit::ANIMATION:
		return "<animation>";
	case PropertyUnit::NUMBER:	return std::to_string(std::get<float>(value));
	case PropertyUnit::PX:		return std::to_string(std::get<float>(value)) + "px";
	case PropertyUnit::DEG:		return std::to_string(std::get<float>(value)) + "deg";
	case PropertyUnit::RAD:		return std::to_string(std::get<float>(value)) + "rad";
	case PropertyUnit::EM:		return std::to_string(std::get<float>(value)) + "em";
	case PropertyUnit::REM:		return std::to_string(std::get<float>(value)) + "rem";
	case PropertyUnit::PERCENT:	return std::to_string(std::get<float>(value)) + "%";
	case PropertyUnit::INCH:	return std::to_string(std::get<float>(value)) + "in";
	case PropertyUnit::CM:		return std::to_string(std::get<float>(value)) + "cm";
	case PropertyUnit::MM:		return std::to_string(std::get<float>(value)) + "mm";
	case PropertyUnit::PT:		return std::to_string(std::get<float>(value)) + "pt";
	case PropertyUnit::PC:		return std::to_string(std::get<float>(value)) + "pc";
	case PropertyUnit::VW:		return std::to_string(std::get<float>(value)) + "vw";
	case PropertyUnit::VH:		return std::to_string(std::get<float>(value)) + "vh";
	case PropertyUnit::VMIN:		return std::to_string(std::get<float>(value)) + "vmin";
	case PropertyUnit::VMAX:		return std::to_string(std::get<float>(value)) + "vmax";
	default:
		return "<unknown, " + std::to_string((uint32_t)unit) + ">";
	}
}

float Property::GetFloat() const {
	switch (unit) {
	case PropertyUnit::NUMBER:
	case PropertyUnit::PX:
	case PropertyUnit::DEG:
	case PropertyUnit::RAD:
	case PropertyUnit::EM:
	case PropertyUnit::REM:
	case PropertyUnit::PERCENT:
	case PropertyUnit::INCH:
	case PropertyUnit::CM:
	case PropertyUnit::MM:
	case PropertyUnit::PT:
	case PropertyUnit::PC:
	case PropertyUnit::VW:
	case PropertyUnit::VH:
	case PropertyUnit::VMIN:
	case PropertyUnit::VMAX:
		return std::get<float>(value);
	default:
		return UndefinedFloat;
	}
}

Color Property::GetColor() const {
	switch (unit) {
	case PropertyUnit::COLOUR:
		return std::get<Color>(value);
	default:
		return Color{};
	}
}

int Property::GetKeyword() const {
	switch (unit) {
	case PropertyUnit::KEYWORD:
		return std::get<int>(value);
	default:
		return 0;
	}
}

std::string Property::GetString() const {
	switch (unit) {
	case PropertyUnit::STRING:
		return std::get<std::string>(value);
	default:
		return "";
	}
}

PropertyFloatValue Property::ToFloatValue() const {
	if (unit == PropertyUnit::KEYWORD) {
		switch (std::get<int>(value)) {
		default:
		case 0 /* left/top     */: return { 0.0f, PropertyUnit::PERCENT }; break;
		case 1 /* center       */: return { 50.0f, PropertyUnit::PERCENT }; break;
		case 2 /* right/bottom */: return { 100.0f, PropertyUnit::PERCENT }; break;
		}
	}
	float v = GetFloat();
	if (v == UndefinedFloat) {
		return { v, PropertyUnit::UNKNOWN };
	}
	return { v, unit };
}

template <>
std::string ToString<PropertyFloatValue>(const PropertyFloatValue& v) {
	std::string value = std::to_string(v.value);
	switch (v.unit) {
		case PropertyUnit::PX:		value += "px"; break;
		case PropertyUnit::DEG:		value += "deg"; break;
		case PropertyUnit::RAD:		value += "rad"; break;
		case PropertyUnit::EM:		value += "em"; break;
		case PropertyUnit::REM:		value += "rem"; break;
		case PropertyUnit::PERCENT:	value += "%"; break;
		case PropertyUnit::INCH:		value += "in"; break;
		case PropertyUnit::CM:		value += "cm"; break;
		case PropertyUnit::MM:		value += "mm"; break;
		case PropertyUnit::PT:		value += "pt"; break;
		case PropertyUnit::PC:		value += "pc"; break;
		case PropertyUnit::VW:		value += "vw"; break;
		case PropertyUnit::VH:		value += "vh"; break;
		case PropertyUnit::VMIN:		value += "vmin"; break;
		case PropertyUnit::VMAX:		value += "vmax"; break;
		default:				break;
	}
	return value;
}

}
