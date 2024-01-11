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

std::optional<PropertyFloat> PropertyParseRawFloat(const std::string& value) {
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
	return PropertyFloat { float_value, unit };
}

}
