#pragma once

#include <css/PropertyParser.h>

namespace Rml {

class PropertyParserColour : public PropertyParser {
public:
	PropertyView ParseValue(PropertyId id, const std::string& value) const override;
};

}
