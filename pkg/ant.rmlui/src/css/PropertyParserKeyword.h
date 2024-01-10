#pragma once

#include <css/Property.h>
#include <util/StaticString.h>
#include <tuple>

namespace Rml {

template <StaticString... str>
struct StaticStringArray {
	static constexpr std::array<std::string_view, sizeof...(str)> strs { std::string_view { str.data(), str.length() } ... };
	template <size_t I>
	static int find(const std::string& value) {
		if constexpr (I < sizeof...(str)) {
			if (value == strs[I]) {
				return (int)I;
			}
			return find<I+1>(value);
		}
		return -1;
	}
};

template <StaticString... Keywords>
Property PropertyParseKeyword(PropertyId id, const std::string& value) {
	int v = StaticStringArray<Keywords...>::template find<0>(value);
	if (v == -1) {
		return {};
	}
	return { id, v };
}

}
