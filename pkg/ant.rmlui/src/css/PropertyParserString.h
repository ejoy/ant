#pragma once

#include <css/PropertyParser.h>

namespace Rml {

class PropertyParserString : public PropertyParser {
public:
	PropertyView ParseValue(PropertyId id, const std::string& value) const override;
};

}
