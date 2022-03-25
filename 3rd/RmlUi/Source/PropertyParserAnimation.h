#pragma once

#include "../Include/RmlUi/PropertyParser.h"

namespace Rml {

class PropertyParserAnimation : public PropertyParser {
public:
	enum Type { ANIMATION_PARSER, TRANSITION_PARSER } type;
	PropertyParserAnimation(Type type);
	std::optional<Property> ParseValue(const std::string& value, const ParameterMap& parameters) const override;
};

}
