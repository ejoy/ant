#pragma once

#include "../Include/RmlUi/PropertyParser.h"
#include "PropertyParserNumber.h"

namespace Rml {

class PropertyParserTransform : public PropertyParser {
public:
	PropertyParserTransform();
	std::optional<Property> ParseValue(const std::string& value, const ParameterMap& parameters) const override;

private:
	bool Scan(int& out_bytes_read, const char* str, const char* keyword, const PropertyParser** parsers, PropertyFloat* args, int nargs) const;
	PropertyParserNumber number, length, angle;
};

}
