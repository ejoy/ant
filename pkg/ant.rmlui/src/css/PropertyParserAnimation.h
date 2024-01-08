#pragma once

#include <css/PropertyParser.h>

namespace Rml {

class PropertyParserAnimation : public PropertyParser {
public:
	PropertyView ParseValue(PropertyId id, const std::string& value) const override;
};

class PropertyParserTransition : public PropertyParser {
public:
	PropertyView ParseValue(PropertyId id, const std::string& value) const override;
};

}
