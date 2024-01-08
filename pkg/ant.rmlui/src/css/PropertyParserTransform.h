#pragma once

#include <css/PropertyParser.h>
#include <css/PropertyParserNumber.h>

namespace Rml {

class PropertyParserTransform : public PropertyParser {
public:
	PropertyParserTransform();
	PropertyView ParseValue(PropertyId id, const std::string& value) const override;

private:
	bool Scan(int& out_bytes_read, const char* str, const char* keyword, const PropertyParserNumber** parsers, PropertyFloat* args, int nargs) const;
	PropertyParserNumber number, length, angle;
};

}
