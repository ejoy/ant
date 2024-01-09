#pragma once

#include <css/PropertyParser.h>
#include <util/StaticString.h>
#include <tuple>

namespace Rml {

template <StaticString... Keywords>
class PropertyParserKeyword : public PropertyParser {
public:
	static constexpr std::array<std::string_view, sizeof...(Keywords)> keywords { std::string_view { Keywords.data(), Keywords.length() } ... };
	template <size_t I>
	int Find(const std::string& value) const {
		if constexpr (I < sizeof...(Keywords)) {
			if (value == keywords[I]) {
				return (int)I;
			}
			return Find<I+1>(value);
		}
		return -1;
	}
	Property ParseValue(PropertyId id, const std::string& value) const override {
		auto v = Find<0>(value);
		if (v == -1) {
			return {};
		}
		return { id, v };
	}
};

}
