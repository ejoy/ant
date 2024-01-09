#pragma once

#include <css/PropertyParser.h>
#include <css/PropertyParserNumber.h>

namespace Rml {

class PropertyParserTransform : public PropertyParser {
public:
	PropertyParserTransform();
	Property ParseValue(PropertyId id, const std::string& value) const override;
};

}
