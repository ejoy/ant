#pragma once

#include <css/PropertyParser.h>

namespace Rml {

class PropertyParserString : public PropertyParser {
public:
	Property ParseValue(PropertyId id, const std::string& value) const override;
};

}
