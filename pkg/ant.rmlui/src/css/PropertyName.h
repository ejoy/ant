#pragma once

#include <util/EnumName.h>

namespace Rml {

enum class PropertyNameStyle {
	Camel,
	Kebab,
};

constexpr char ToLower(const char c) {
	return (c >= 'A' && c <= 'Z') ? c + ('a' - 'A') : c;
}

constexpr bool IsUpper(const char c) {
	return c >= 'A' && c <= 'Z';
}

template <PropertyNameStyle Style, auto E>
constexpr auto PropertyName_() {
	constexpr auto rawname = EnumNameV<E>;
	size_t i = 1;
	size_t sz = 0;
	std::array<char, 256> name = {};
	if (rawname[0] == '_') {
		if constexpr (Style == PropertyNameStyle::Camel) {
			name[sz++] = '-';
		}
		name[sz++] = ToLower(rawname[1]);
		i = 2;
	}
	else {
		name[sz++] = ToLower(rawname[0]);
	}
	if constexpr (Style == PropertyNameStyle::Camel) {
		for (; i < rawname.size(); ++i) {
			name[sz++] = rawname[i];
		}
	}
	else {
		for (; i < rawname.size(); ++i) {
			auto c = rawname[i];
			if (IsUpper(c)) {
				name[sz++] = '-';
				name[sz++] = ToLower(c);
			}
			else {
				name[sz++] = c;
			}
		}
	}
	name[sz] = '\0';
	return std::make_pair(name, sz);
}

template <auto Data>
constexpr auto& MakeItStatic() {
	return Data;
}

template <PropertyNameStyle Style, auto E>
constexpr auto PropertyName() {
	constexpr auto& data = MakeItStatic<PropertyName_<Style, E>()>();
	return std::string_view { data.first.data(), data.second };
}

template <PropertyNameStyle Style, auto E>
constexpr auto PropertyNameV = PropertyName<Style, E>();

}
