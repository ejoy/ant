#pragma once

#include <css/PropertyParser.h>

namespace Rml {

class PropertyParserAnimation : public PropertyParser {
public:
	Property ParseValue(PropertyId id, const std::string& value) const override;
};

class PropertyParserTransition : public PropertyParser {
public:
	Property ParseValue(PropertyId id, const std::string& value) const override;
};

}
