#pragma once

#include <css/PropertyParser.h>
#include <css/Property.h>

namespace Rml {

class PropertyParserNumber : public PropertyParser {
public:
	enum class UnitMark : uint8_t {
		Number,
		Length,
		LengthPercent,
		Angle,
	};

	PropertyParserNumber(UnitMark units);
	std::optional<Property> ParseValue(const std::string& value) const override;
private:
	UnitMark units;
};

}
