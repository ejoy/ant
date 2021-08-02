#pragma once

#include "Header.h"
#include <variant>
#include <string>

namespace Rml {

using EventVariant = std::variant<
	std::monostate,
	float,
	int,
	std::string
>;

using Variant = std::variant<
	std::monostate,
	bool,
	float,
	int,
	std::string
>;

template <typename T>
T GetVariant(const Variant& variant, T def = T{}) {
	if (const T* r = std::get_if<T>(&variant)) {
		return *r;
	}
	return def;
}

template <typename V>
struct CopyVariantVisitor {
	template <typename T>
	V operator()(T const& v) {
		return v;
	}
};

inline Variant CopyVariant(const EventVariant& from) {
	return std::visit(CopyVariantVisitor<Variant> {}, from);
}

}
