#pragma once

#include <css/PropertyParser.h>

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
	PropertyView ParseValue(PropertyId id, const std::string& value) const override;
	std::optional<PropertyFloat> ParseValue(const std::string& value) const;

private:
	UnitMark units;
};

}
