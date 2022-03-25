#pragma once

#include "../Include/RmlUi/PropertyParser.h"
#include <unordered_map>

namespace Rml {

using ParameterMap = std::unordered_map< std::string, int >;

class PropertyParserKeyword : public PropertyParser {
public:
	std::optional<Property> ParseValue(const std::string& value) const override;
	ParameterMap parameters;
};

}
