#pragma once

#include <css/Property.h>
#include <util/AlwaysFalse.h>
#include <optional>

namespace Rml {

std::optional<PropertyFloat> PropertyParseRawFloat(const std::string& value);

enum class PropertyParseNumberUnit : uint8_t {
	Number,
	Length,
	LengthPercent,
	Angle,
};

template <PropertyParseNumberUnit units>
std::optional<PropertyFloat> PropertyParseFloat(const std::string& value) {
	auto f = PropertyParseRawFloat(value);
	if (!f) {
		return std::nullopt;
	}
	if constexpr (units == PropertyParseNumberUnit::Number) {
		switch (f->unit) {
		case PropertyUnit::NUMBER:
			return f;
		default:
			return std::nullopt;
		}
	}
	else if constexpr (units == PropertyParseNumberUnit::Length) {
		switch (f->unit) {
		case PropertyUnit::RAD:
		case PropertyUnit::DEG:
		case PropertyUnit::PERCENT:
			return std::nullopt;
		case PropertyUnit::NUMBER:
			if (f->value == 0.f) {
				return PropertyFloat { 0.f, PropertyUnit::PX };
			}
			return std::nullopt;
		default:
			return f;
		}
	}
	else if constexpr (units == PropertyParseNumberUnit::LengthPercent) {
		switch (f->unit) {
		case PropertyUnit::RAD:
		case PropertyUnit::DEG:
			return std::nullopt;
		case PropertyUnit::NUMBER:
			if (f->value == 0.f) {
				return PropertyFloat { 0.f, PropertyUnit::PX };
			}
			return std::nullopt;
		default:
			return f;
		}
	}
	else if constexpr (units == PropertyParseNumberUnit::Angle) {
		switch (f->unit) {
		case PropertyUnit::RAD:
		case PropertyUnit::DEG:
			return f;
		case PropertyUnit::NUMBER:
			if (f->value == 0.f) {
				return PropertyFloat { 0.f, PropertyUnit::RAD };
			}
			return std::nullopt;
		default:
			return std::nullopt;
		}
	}
	else {
		static_assert(always_false_v<decltype(units)>, "unknown number units!");
	}
}

template <PropertyParseNumberUnit units>
Property PropertyParseNumber(PropertyId id, const std::string& value) {
	auto v = PropertyParseFloat<units>(value);
	if (v) {
		return { id, *v };
	}
	return {};
}

}
