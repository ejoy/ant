#pragma once

#include <variant>
#include <string>

namespace Rml {


using Variant = std::variant<
	std::monostate,
	bool,
	float,
	int,
	std::string
>;

namespace VariantHelper {
	template <typename T>
	T Get(const Variant& variant, T def = T{}) {
		if (const T* r = std::get_if<T>(&variant)) {
			return *r;
		}
		return def;
	}

	template <typename T>
	T ConvertGet(const Variant& variant) {
		return std::visit(
			[] (auto const& val) {
				if constexpr (std::is_convertible_v<decltype(val), T>)
					return T(val);
				else {
					return T{};
				}
			},
			variant);
	}

	struct ToStringVisitor {
		std::string operator()(std::monostate const& v) {
			return "";
		}
		std::string operator()(bool const& v) {
			return v? "true": "false";
		}
		std::string operator()(float const& v) {
			return std::to_string(v);
		}
		std::string operator()(int const& v) {
			return std::to_string(v);
		}
		std::string operator()(std::string const& v) {
			return v;
		}
	};
	inline std::string ToString(const Variant& variant) {
		return std::visit(ToStringVisitor {}, variant);
	}
}

}
