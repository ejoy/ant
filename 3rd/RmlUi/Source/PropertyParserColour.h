#pragma once

#include "../Include/RmlUi/PropertyParser.h"
#include "../Include/RmlUi/Types.h"

namespace Rml {

class PropertyParserColour : public PropertyParser {
public:
	std::optional<Property> ParseValue(const std::string& value, const ParameterMap& parameters) const override;
};

}
