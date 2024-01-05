#include <css/PropertyParserNumber.h>
#include <unordered_map>
#include <stdlib.h>

namespace Rml {

static const std::unordered_map<std::string, PropertyUnit> g_property_unit_string_map = {
	{"", PropertyUnit::NUMBER},
	{"%", PropertyUnit::PERCENT},
	{"px", PropertyUnit::PX},
	{"em", PropertyUnit::EM},
	{"rem", PropertyUnit::REM},
	{"in", PropertyUnit::INCH},
	{"cm", PropertyUnit::CM},
	{"mm", PropertyUnit::MM},
	{"pt", PropertyUnit::PT},
	{"pc", PropertyUnit::PC},
	{"deg", PropertyUnit::DEG},
	{"rad", PropertyUnit::RAD},
	{"vw", PropertyUnit::VW},
	{"vh", PropertyUnit::VH},
	{"vmin", PropertyUnit::VMIN},
	{"vmax", PropertyUnit::VMAX},
};

static constexpr bool PropertyIsAngle(PropertyUnit unit) {
	return (unit == PropertyUnit::RAD) || (unit == PropertyUnit::DEG);
}

static constexpr bool PropertyIsNumber(PropertyUnit unit) {
	return unit == PropertyUnit::NUMBER;
}

static constexpr bool PropertyIsPercent(PropertyUnit unit) {
	return unit == PropertyUnit::PERCENT;
}

PropertyParserNumber::PropertyParserNumber(UnitMark units)
	: units(units)
{}

std::optional<Property> PropertyParserNumber::ParseValue(const std::string& value) const {
	// Find the beginning of the unit string in 'value'.
	size_t unit_pos = 0;
	for (size_t i = value.size(); i--;) {
		const char c = value[i];
		if (c >= '0' && c <= '9') {
			unit_pos = i + 1;
			break;
		}
	}

	std::string str_number = value.substr(0, unit_pos);
	std::string str_unit = value.substr(unit_pos);

	char* str_end = nullptr;
	float float_value = strtof(str_number.c_str(), &str_end);
	if (str_number.c_str() == str_end) {
		// Number conversion failed
		return std::nullopt;
	}

	const auto it = g_property_unit_string_map.find(str_unit);
	if (it == g_property_unit_string_map.end()) {
		// Invalid unit name
		return std::nullopt;
	}

	const PropertyUnit unit = it->second;

	switch (units) {
	case UnitMark::Number:
		if (PropertyIsNumber(unit)) {
			return PropertyFloat { float_value, unit };
		}
		break;
	case UnitMark::Length:
		if (!PropertyIsAngle(unit) && !PropertyIsNumber(unit) && !PropertyIsPercent(unit)) {
			return PropertyFloat { float_value, unit };
		}
		break;
	case UnitMark::LengthPercent:
		if (!PropertyIsAngle(unit) && !PropertyIsNumber(unit)) {
			return PropertyFloat { float_value, unit };
		}
		break;
	case UnitMark::Angle:
		if (PropertyIsAngle(unit)) {
			return PropertyFloat { float_value, unit };
		}
		break;
	}

	if (unit == PropertyUnit::NUMBER && float_value == 0.f) {
		switch (units) {
		case UnitMark::Angle:
			return PropertyFloat { 0.f, PropertyUnit::RAD };
		case UnitMark::Length:
		case UnitMark::LengthPercent:
			return PropertyFloat { 0.f, PropertyUnit::PX };
		default:
			break;
		}
	}
	return std::nullopt;
}

}
