#pragma once

#include <core/PropertyParser.h>
#include <unordered_map>

namespace Rml {

class PropertyParserKeyword : public PropertyParser {
public:
	std::optional<Property> ParseValue(const std::string& value) const override;
	std::unordered_map<std::string, int> parameters;
};

}
