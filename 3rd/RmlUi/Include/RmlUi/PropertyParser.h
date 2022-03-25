#pragma once

#include <optional>
#include <string>

namespace Rml {

class Property;

class PropertyParser {
public:
	virtual std::optional<Property> ParseValue(const std::string& value) const = 0;
};

}
