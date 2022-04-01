#include <core/Property.h>

namespace Rml {

struct ToStringVisitor {
	std::string operator()(const PropertyFloat& p) {
		return p.ToString();
	}
	std::string operator()(const PropertyKeyword& p) {
		return "<keyword," + std::to_string(p) + ">";
	}
	std::string operator()(const Color& p) {
		return p.ToString();
	}
	std::string operator()(const std::string& p) {
		return p;
	}
	std::string operator()(const Transform& p) {
		return p.ToString();
	}
	std::string operator()(const Transitions& p) {
		return "<transition>";
	}
	std::string operator()(const AnimationList& p) {
		return "<animation>";
	}
};

std::string Property::ToString() const {
	return std::visit(ToStringVisitor{}, (const PropertyVariant&)*this);
}

struct InterpolateVisitor {
	const PropertyVariant& other_variant;
	float alpha;
	template <typename T>
	Property operator()(const T& p0) {
		return interpolate(p0, std::get<T>(other_variant));
	}

	template <typename T>
	T interpolate(const T& p0, const T& p1) {
		return InterpolateFallback(p0, p1, alpha);
	}
};

template<>
PropertyFloat InterpolateVisitor::interpolate<PropertyFloat>(const PropertyFloat& p0, const PropertyFloat& p1) {
	return p0.Interpolate(p1, alpha);
}
template<>
Color InterpolateVisitor::interpolate<Color>(const Color& p0, const Color& p1) {
	return p0.Interpolate(p1, alpha);
}
template<>
Transform InterpolateVisitor::interpolate<Transform>(const Transform& p0, const Transform& p1) {
	return p0.Interpolate(p1, alpha);
}

Property Property::Interpolate(const Property& other, float alpha) const {
	if (index() != other.index()) {
		return InterpolateFallback(*this, other, alpha);
	}
	return std::visit(InterpolateVisitor{ other, alpha }, (const PropertyVariant&)*this);
}

struct AllowInterpolateVisitor {
	template <typename T>
	bool operator()(const T&) { return true; }
};
template <> bool AllowInterpolateVisitor::operator()<PropertyKeyword>(const PropertyKeyword&) { return false; }
template <> bool AllowInterpolateVisitor::operator()<std::string>(const std::string&) { return false; }
template <> bool AllowInterpolateVisitor::operator()<Transitions>(const Transitions&) { return false; }
template <> bool AllowInterpolateVisitor::operator()<AnimationList>(const AnimationList&) { return false; }

bool Property::AllowInterpolate() const {
	return std::visit(AllowInterpolateVisitor{}, (const PropertyVariant&)*this);
}

}
