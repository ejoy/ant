#pragma once

#include <css/Property.h>
#include <css/EnumName.h>
#include <util/StaticString.h>
#include <tuple>

namespace Rml {

template <StaticString... str>
struct StaticStringArray {
	static constexpr std::array<std::string_view, sizeof...(str)> strs { std::string_view { str.data(), str.length() } ... };
	template <size_t I>
	static size_t find(const std::string& value) {
		if constexpr (I < sizeof...(str)) {
			if (value == strs[I]) {
				return (size_t)I;
			}
			return find<I+1>(value);
		}
		return (size_t)-1;
	}
};

template <StaticString... Keywords>
Property PropertyParseKeyword(PropertyId id, const std::string& value) {
	size_t v = StaticStringArray<Keywords...>::template find<0>(value);
	if (v == (size_t)-1 || v > (size_t)std::numeric_limits<PropertyKeyword>::max()) {
		return {};
	}
	return { id, (PropertyKeyword)v };
}

template <typename E>
	requires(std::is_enum_v<E>)
Property PropertyParseKeyword(PropertyId id, const std::string& value) {
	size_t v = GetCssEnumIndex<CssEnumNameStyle::Kebab, E>(value);
	if (v == (size_t)-1 || v > (size_t)std::numeric_limits<PropertyKeyword>::max()) {
		return {};
	}
	return { id, (PropertyKeyword)v };
}

}
