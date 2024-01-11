#pragma once

#include <util/EnumName.h>
#include <bee/nonstd/to_underlying.h>

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
constexpr auto PropertyNameRaw() {
	constexpr auto rawname = EnumNameV<E>;
	size_t i = 1;
	size_t sz = 0;
	std::array<char, 32> name = {};
	if (rawname[0] == '_') {
		if constexpr (Style != PropertyNameStyle::Camel) {
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

template <PropertyNameStyle Style, auto E>
constexpr auto PropertyNameZip() {
	constexpr auto pair = PropertyNameRaw<Style, E>();
	constexpr auto buf = pair.first;
	constexpr auto size = pair.second;
	std::array<char, size> newbuf;
	std::copy(buf.begin(), std::next(buf.begin(), size), newbuf.begin());
	return newbuf;
}

template <auto Data>
constexpr auto const& MakeItStatic() {
	return Data;
}

template <PropertyNameStyle Style, auto E>
constexpr auto PropertyName() {
	constexpr auto const& data = MakeItStatic<PropertyNameZip<Style, E>()>();
	return std::string_view { data.data(), data.size() };
}

template <PropertyNameStyle Style, auto E>
constexpr auto PropertyNameV = PropertyName<Style, E>();

template <PropertyNameStyle Style, typename E, std::underlying_type_t<E> I = 0>
auto GetPropertyName(E id) {
	if constexpr (I < EnumCountV<E>) {
		if (I == std::to_underlying<E>(id)) {
			return PropertyNameV<Style, static_cast<E>(I)>;
		}
		else {
			return GetPropertyName<Style, E, I+1>(id);
		}
	}
	return std::string_view {};
}

}
