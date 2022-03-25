#pragma once

#include "../Include/RmlUi/PropertyParser.h"

namespace Rml {

class PropertyParserKeyword : public PropertyParser {
public:
	std::optional<Property> ParseValue(const std::string& value, const ParameterMap& parameters) const override;
};

}
