#pragma once

#include <css/PropertyParser.h>
#include <unordered_map>

namespace Rml {

class PropertyParserKeyword : public PropertyParser {
public:
	PropertyView ParseValue(PropertyId id, const std::string& value) const override;
	std::unordered_map<std::string, int> parameters;
};

}
