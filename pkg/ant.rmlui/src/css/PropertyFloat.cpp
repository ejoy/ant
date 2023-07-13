#include <css/PropertyFloat.h>
#include <core/Document.h>
#include <core/Element.h>
#include <glm/gtx/compatibility.hpp>

#include <version>
#if defined(__cpp_lib_math_constants)
#	include <numbers>
static constexpr float const_pi = std::numbers::pi_v<float>;
#else
static constexpr float const_pi = static_cast<float>(3.141592653589793);
#endif

namespace Rml {

PropertyFloat::PropertyFloat(float v, PropertyUnit unit)
    : value(v)
    , unit(unit)
{}

std::string PropertyFloat::ToString() const {
    std::string v = std::to_string(value);
    switch (unit) {
        case PropertyUnit::PX:		v += "px"; break;
        case PropertyUnit::DEG:		v += "deg"; break;
        case PropertyUnit::RAD:		v += "rad"; break;
        case PropertyUnit::EM:		v += "em"; break;
        case PropertyUnit::REM:		v += "rem"; break;
        case PropertyUnit::PERCENT:	v += "%"; break;
        case PropertyUnit::INCH:	v += "in"; break;
        case PropertyUnit::CM:		v += "cm"; break;
        case PropertyUnit::MM:		v += "mm"; break;
        case PropertyUnit::PT:		v += "pt"; break;
        case PropertyUnit::PC:		v += "pc"; break;
        case PropertyUnit::VW:		v += "vw"; break;
        case PropertyUnit::VH:		v += "vh"; break;
        case PropertyUnit::VMIN:	v += "vmin"; break;
        case PropertyUnit::VMAX:	v += "vmax"; break;
        default: break;
    }
    return v;
}

float PropertyFloat::ComputeAngle() const {
	switch (unit) {
	case PropertyUnit::RAD:
		return value;
	case PropertyUnit::DEG:
		return value * (const_pi / 180.0f);
	default:
		return 0.0f;
	}
}

float PropertyFloat::Compute(const Element* e) const {
	static constexpr float PixelsPerInch = 96.0f;
	switch (unit) {
	case PropertyUnit::NUMBER:
	case PropertyUnit::PX:
	case PropertyUnit::RAD:
		return value;
	case PropertyUnit::EM:
		return value * e->GetFontSize();
	case PropertyUnit::REM:
		return value * e->GetOwnerDocument()->GetBody()->GetFontSize();
	case PropertyUnit::DEG:
		return value * (const_pi / 180.0f);
	case PropertyUnit::VW:
		return value * e->GetOwnerDocument()->GetDimensions().w * 0.01f;
	case PropertyUnit::VH:
		return value * e->GetOwnerDocument()->GetDimensions().h * 0.01f;
	case PropertyUnit::VMIN: {
		auto const& size = e->GetOwnerDocument()->GetDimensions();
		return value * std::min(size.w, size.h) * 0.01f;
	}
	case PropertyUnit::VMAX: {
		auto const& size = e->GetOwnerDocument()->GetDimensions();
		return value * std::max(size.w, size.h) * 0.01f;
	}
	case PropertyUnit::INCH: // inch
		return value * PixelsPerInch;
	case PropertyUnit::CM: // centimeter
		return value * PixelsPerInch * (1.0f / 2.54f);
	case PropertyUnit::MM: // millimeter
		return value * PixelsPerInch * (1.0f / 25.4f);
	case PropertyUnit::PT: // point
		return value * PixelsPerInch * (1.0f / 72.0f);
	case PropertyUnit::PC: // pica
		return value * PixelsPerInch * (1.0f / 6.0f);
	default:
		return 0.0f;
	}
}

float PropertyFloat::ComputeW(const Element* e) const {
	if (unit == PropertyUnit::PERCENT) {
		return value * e->GetBounds().size.w * 0.01f;
	}
	return Compute(e);
}

float PropertyFloat::ComputeH(const Element* e) const {
	if (unit == PropertyUnit::PERCENT) {
		return value * e->GetBounds().size.h * 0.01f;
	}
	return Compute(e);
}

static PropertyFloat interpolate(const PropertyFloat& p0, const PropertyFloat& p1, float alpha) {
	if (p0.unit == p1.unit) {
		float value = glm::lerp(p0.value, p1.value, alpha);
		return {value, p0.unit};
	}
	
	switch (p0.unit) {
	case PropertyUnit::EM: case PropertyUnit::REM:
	case PropertyUnit::VW: case PropertyUnit::VH:
	case PropertyUnit::VMIN: case PropertyUnit::VMAX:
	case PropertyUnit::PERCENT:
		return InterpolateFallback(p0, p1, alpha);
	default:
		break;
	}
	switch (p1.unit) {
	case PropertyUnit::EM: case PropertyUnit::REM:
	case PropertyUnit::VW: case PropertyUnit::VH:
	case PropertyUnit::VMIN: case PropertyUnit::VMAX:
	case PropertyUnit::PERCENT:
		return InterpolateFallback(p0, p1, alpha);
	default:
		break;
	}

	float a0 = p0.Compute(nullptr);
	float a1 = p1.Compute(nullptr);
	float value = glm::lerp(a0, a1, alpha);
	if ((p0.unit == PropertyUnit::RAD || p0.unit == PropertyUnit::DEG) &&
		(p1.unit == PropertyUnit::RAD || p1.unit == PropertyUnit::DEG)
	) {
		return {value, PropertyUnit::RAD};
	}
	return {value, PropertyUnit::PX};
}

PropertyFloat PropertyFloat::Interpolate(const PropertyFloat& p1, float alpha) const {
	return interpolate(*this, p1, alpha);
}

}
