#pragma once

#include "core/PropertyParser.h"

namespace Rml {

class PropertyParserString : public PropertyParser {
public:
	std::optional<Property> ParseValue(const std::string& value) const override;
};

}
