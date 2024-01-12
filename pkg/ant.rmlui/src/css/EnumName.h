#pragma once

#include <util/Enum.h>
#include <bee/nonstd/to_underlying.h>

namespace Rml {

enum class CssEnumNameStyle {
	Camel,
	Kebab,
};

constexpr char ToLower(const char c) {
	return (c >= 'A' && c <= 'Z') ? c + ('a' - 'A') : c;
}

constexpr bool IsUpper(const char c) {
	return c >= 'A' && c <= 'Z';
}

template <CssEnumNameStyle Style, auto E>
constexpr auto CssEnumNameRaw() {
	constexpr auto rawname = EnumNameV<E>;
	size_t i = 1;
	size_t sz = 0;
	std::array<char, 32> name = {};
	if (rawname[0] == '_') {
		if constexpr (Style != CssEnumNameStyle::Camel) {
			name[sz++] = '-';
		}
		name[sz++] = ToLower(rawname[1]);
		i = 2;
	}
	else {
		name[sz++] = ToLower(rawname[0]);
	}
	if constexpr (Style == CssEnumNameStyle::Camel) {
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

template <CssEnumNameStyle Style, auto E>
constexpr auto CssEnumNameZip() {
	constexpr auto pair = CssEnumNameRaw<Style, E>();
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

template <CssEnumNameStyle Style, auto E>
constexpr auto CssEnumName() {
	constexpr auto const& data = MakeItStatic<CssEnumNameZip<Style, E>()>();
	return std::string_view { data.data(), data.size() };
}

template <CssEnumNameStyle Style, auto E>
constexpr auto CssEnumNameV = CssEnumName<Style, E>();

template <CssEnumNameStyle Style, typename E, std::underlying_type_t<E> I = 0>
auto GetCssEnumName(E id) {
	if constexpr (I < EnumCountV<E>) {
		if (I == std::to_underlying<E>(id)) {
			return CssEnumNameV<Style, static_cast<E>(I)>;
		}
		else {
			return GetCssEnumName<Style, E, I+1>(id);
		}
	}
	return std::string_view {};
}

template <CssEnumNameStyle Style, typename E, size_t I = 0>
size_t GetCssEnumIndex(std::string_view name) {
	if constexpr (I < EnumCountV<E>) {
		if (name == CssEnumNameV<Style, static_cast<E>(I)>) {
			return (size_t)I;
		}
		return GetCssEnumIndex<E, I+1>(name);
	}
	return (size_t)-1;
}

}
