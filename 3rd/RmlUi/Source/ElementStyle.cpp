#include "../Include/RmlUi/ElementStyle.h"
#include "../Include/RmlUi/Document.h"
#include <algorithm>
#include <numbers>

namespace Rml {
	
float ComputeProperty(FloatValue fv, Element* e) {
	static constexpr float PixelsPerInch = 96.0f;
	switch (fv.unit) {
	case Property::NUMBER:
	case Property::PX:
	case Property::RAD:
		return fv.value;
	case Property::EM:
		return fv.value * e->GetFontSize();
	case Property::REM:
		return fv.value * e->GetOwnerDocument()->GetBody()->GetFontSize();
	case Property::DEG:
		return fv.value * (std::numbers::pi_v<float> / 180.0f);
	case Property::VW:
		return fv.value * e->GetOwnerDocument()->GetDimensions().w * 0.01f;
	case Property::VH:
		return fv.value * e->GetOwnerDocument()->GetDimensions().h * 0.01f;
	case Property::VMIN: {
		auto const& size = e->GetOwnerDocument()->GetDimensions();
		return fv.value * std::min(size.w, size.h) * 0.01f;
	}
	case Property::VMAX: {
		auto const& size = e->GetOwnerDocument()->GetDimensions();
		return fv.value * std::max(size.w, size.h) * 0.01f;
	}
	case Property::INCH: // inch
		return fv.value * PixelsPerInch;
	case Property::CM: // centimeter
		return fv.value * PixelsPerInch * (1.0f / 2.54f);
	case Property::MM: // millimeter
		return fv.value * PixelsPerInch * (1.0f / 25.4f);
	case Property::PT: // point
		return fv.value * PixelsPerInch * (1.0f / 72.0f);
	case Property::PC: // pica
		return fv.value * PixelsPerInch * (1.0f / 6.0f);
	default:
		return 0.0f;
	}
}

float ComputePropertyW(FloatValue fv, Element* e) {
	if (fv.unit == Property::PERCENT) {
		return fv.value * e->GetMetrics().frame.size.w * 0.01f;
	}
	return ComputeProperty(fv, e);
}

float ComputePropertyH(FloatValue fv, Element* e) {
	if (fv.unit == Property::PERCENT) {
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

} // namespace Rml
