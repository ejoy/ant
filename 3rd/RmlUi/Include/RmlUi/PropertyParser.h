#pragma once

#include <optional>
#include <string>
#include <unordered_map>

namespace Rml {

using ParameterMap = std::unordered_map< std::string, int >;
class Property;

class PropertyParser {
public:
	virtual std::optional<Property> ParseValue(const std::string& value, const ParameterMap& parameters) const = 0;
};

}
