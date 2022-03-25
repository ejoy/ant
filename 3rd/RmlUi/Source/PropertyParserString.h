#pragma once

#include "../Include/RmlUi/PropertyParser.h"

namespace Rml {

class PropertyParserString : public PropertyParser {
public:
	std::optional<Property> ParseValue(const std::string& value) const override;
};

}
