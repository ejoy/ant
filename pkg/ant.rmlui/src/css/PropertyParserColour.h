#pragma once

#include <css/PropertyParser.h>

namespace Rml {

class PropertyParserColour : public PropertyParser {
public:
	Property ParseValue(PropertyId id, const std::string& value) const override;
};

}
