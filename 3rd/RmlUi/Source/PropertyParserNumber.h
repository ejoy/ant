#pragma once

#include "../Include/RmlUi/PropertyParser.h"
#include "../Include/RmlUi/Property.h"

namespace Rml {

class PropertyParserNumber : public PropertyParser {
public:
	enum class UnitMark {
		Number,
		Length,
		LengthPercent,
		NumberLengthPercent,
		Angle,
	};

	PropertyParserNumber(UnitMark units);
	std::optional<Property> ParseValue(const std::string& value) const override;
private:
	UnitMark units;
};

}
