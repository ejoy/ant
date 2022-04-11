#pragma once

#include <core/PropertyParser.h>

namespace Rml {

class PropertyParserColour : public PropertyParser {
public:
	std::optional<Property> ParseValue(const std::string& value) const override;
};

}
