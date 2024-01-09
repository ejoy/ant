#pragma once

#include <css/PropertyParser.h>
#include <optional>

namespace Rml {

enum class PropertyParseNumberUnit : uint8_t {
	Number,
	Length,
	LengthPercent,
	Angle,
};

std::optional<PropertyFloat> PropertyParseRawNumber(const std::string& value);

static constexpr bool PropertyIsAngle(PropertyUnit unit) {
	return (unit == PropertyUnit::RAD) || (unit == PropertyUnit::DEG);
}

static constexpr bool PropertyIsNumber(PropertyUnit unit) {
	return unit == PropertyUnit::NUMBER;
}

static constexpr bool PropertyIsPercent(PropertyUnit unit) {
	return unit == PropertyUnit::PERCENT;
}

template <PropertyParseNumberUnit units>
std::optional<PropertyFloat> PropertyParseNumber(const std::string& value) {
	auto f = PropertyParseRawNumber(value);
	if (!f) {
		return std::nullopt;
	}
	switch (units) {
	case PropertyParseNumberUnit::Number:
		if (PropertyIsNumber(f->unit)) {
			return f;
		}
		break;
	case PropertyParseNumberUnit::Length:
		if (!PropertyIsAngle(f->unit) && !PropertyIsNumber(f->unit) && !PropertyIsPercent(f->unit)) {
			return f;
		}
		break;
	case PropertyParseNumberUnit::LengthPercent:
		if (!PropertyIsAngle(f->unit) && !PropertyIsNumber(f->unit)) {
			return f;
		}
		break;
	case PropertyParseNumberUnit::Angle:
		if (PropertyIsAngle(f->unit)) {
			return f;
		}
		break;
	}

	if (f->unit == PropertyUnit::NUMBER && f->value == 0.f) {
		switch (units) {
		case PropertyParseNumberUnit::Angle:
			return PropertyFloat { 0.f, PropertyUnit::RAD };
		case PropertyParseNumberUnit::Length:
		case PropertyParseNumberUnit::LengthPercent:
			return PropertyFloat { 0.f, PropertyUnit::PX };
		default:
			break;
		}
	}
	return std::nullopt;
}

template <PropertyParseNumberUnit units>
class PropertyParserNumber : public PropertyParser {
public:
	Property ParseValue(PropertyId id, const std::string& value) const override {
		auto v = PropertyParseNumber<units>(value);
		if (v) {
			return { id, *v };
		}
		return {};
	}
};

}
