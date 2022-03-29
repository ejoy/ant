#pragma once

#include "core/PropertyParser.h"
#include "core/Types.h"

namespace Rml {

class PropertyParserColour : public PropertyParser {
public:
	std::optional<Property> ParseValue(const std::string& value) const override;
};

}
