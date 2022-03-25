#pragma once

#include "../Include/RmlUi/PropertyParser.h"
#include "../Include/RmlUi/Property.h"

namespace Rml {

class PropertyParserNumber : public PropertyParser {
public:
	PropertyParserNumber(Property::UnitMark units);
	std::optional<Property> ParseValue(const std::string& value, const ParameterMap& parameters) const override;

private:
	Property::UnitMark units;
};

}
