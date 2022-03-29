#pragma once

#include "core/PropertyParser.h"

namespace Rml {

class PropertyParserAnimation : public PropertyParser {
public:
	std::optional<Property> ParseValue(const std::string& value) const override;
};

class PropertyParserTransition : public PropertyParser {
public:
	std::optional<Property> ParseValue(const std::string& value) const override;
};

}
