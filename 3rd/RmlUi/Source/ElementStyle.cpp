#include "../Include/RmlUi/ElementStyle.h"
#include "../Include/RmlUi/Document.h"
#include <algorithm>
#include <numbers>

namespace Rml {
	
float ComputeProperty(PropertyFloatValue fv, Element* e) {
	static constexpr float PixelsPerInch = 96.0f;
	switch (fv.unit) {
	case PropertyUnit::NUMBER:
	case PropertyUnit::PX:
	case PropertyUnit::RAD:
		return fv.value;
	case PropertyUnit::EM:
		return fv.value * e->GetFontSize();
	case PropertyUnit::REM:
		return fv.value * e->GetOwnerDocument()->GetBody()->GetFontSize();
	case PropertyUnit::DEG:
		return fv.value * (std::numbers::pi_v<float> / 180.0f);
	case PropertyUnit::VW:
		return fv.value * e->GetOwnerDocument()->GetDimensions().w * 0.01f;
	case PropertyUnit::VH:
		return fv.value * e->GetOwnerDocument()->GetDimensions().h * 0.01f;
	case PropertyUnit::VMIN: {
		auto const& size = e->GetOwnerDocument()->GetDimensions();
		return fv.value * std::min(size.w, size.h) * 0.01f;
	}
	case PropertyUnit::VMAX: {
		auto const& size = e->GetOwnerDocument()->GetDimensions();
		return fv.value * std::max(size.w, size.h) * 0.01f;
	}
	case PropertyUnit::INCH: // inch
		return fv.value * PixelsPerInch;
	case PropertyUnit::CM: // centimeter
		return fv.value * PixelsPerInch * (1.0f / 2.54f);
	case PropertyUnit::MM: // millimeter
		return fv.value * PixelsPerInch * (1.0f / 25.4f);
	case PropertyUnit::PT: // point
		return fv.value * PixelsPerInch * (1.0f / 72.0f);
	case PropertyUnit::PC: // pica
		return fv.value * PixelsPerInch * (1.0f / 6.0f);
	default:
		return 0.0f;
	}
}

float ComputePropertyW(PropertyFloatValue fv, Element* e) {
	if (fv.unit == PropertyUnit::PERCENT) {
		return fv.value * e->GetMetrics().frame.size.w * 0.01f;
	}
	return ComputeProperty(fv, e);
}

float ComputePropertyH(PropertyFloatValue fv, Element* e) {
	if (fv.unit == PropertyUnit::PERCENT) {
		return fv.value * e->GetMetrics().frame.size.h * 0.01f;
	}
	return ComputeProperty(fv, e);
}

float ComputeProperty(const Property* property, Element* e) {
	return ComputeProperty(property->ToFloatValue(), e);
}

float ComputePropertyW(const Property* property, Element* e) {
	return ComputePropertyW(property->ToFloatValue(), e);
}

float ComputePropertyH(const Property* property, Element* e) {
	return ComputePropertyH(property->ToFloatValue(), e);
}

}
