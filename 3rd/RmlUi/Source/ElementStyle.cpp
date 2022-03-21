#include "../Include/RmlUi/ElementStyle.h"
#include "../Include/RmlUi/Document.h"
#include <algorithm>
#include <numbers>

namespace Rml {
	
float ComputeProperty(FloatValue fv, Element* e) {
	static constexpr float PixelsPerInch = 96.0f;
	switch (fv.unit) {
	case Property::Unit::NUMBER:
	case Property::Unit::PX:
	case Property::Unit::RAD:
		return fv.value;
	case Property::Unit::EM:
		return fv.value * e->GetFontSize();
	case Property::Unit::REM:
		return fv.value * e->GetOwnerDocument()->GetBody()->GetFontSize();
	case Property::Unit::DEG:
		return fv.value * (std::numbers::pi_v<float> / 180.0f);
	case Property::Unit::VW:
		return fv.value * e->GetOwnerDocument()->GetDimensions().w * 0.01f;
	case Property::Unit::VH:
		return fv.value * e->GetOwnerDocument()->GetDimensions().h * 0.01f;
	case Property::Unit::VMIN: {
		auto const& size = e->GetOwnerDocument()->GetDimensions();
		return fv.value * std::min(size.w, size.h) * 0.01f;
	}
	case Property::Unit::VMAX: {
		auto const& size = e->GetOwnerDocument()->GetDimensions();
		return fv.value * std::max(size.w, size.h) * 0.01f;
	}
	case Property::Unit::INCH: // inch
		return fv.value * PixelsPerInch;
	case Property::Unit::CM: // centimeter
		return fv.value * PixelsPerInch * (1.0f / 2.54f);
	case Property::Unit::MM: // millimeter
		return fv.value * PixelsPerInch * (1.0f / 25.4f);
	case Property::Unit::PT: // point
		return fv.value * PixelsPerInch * (1.0f / 72.0f);
	case Property::Unit::PC: // pica
		return fv.value * PixelsPerInch * (1.0f / 6.0f);
	default:
		return 0.0f;
	}
}

float ComputePropertyW(FloatValue fv, Element* e) {
	if (fv.unit == Property::Unit::PERCENT) {
		return fv.value * e->GetMetrics().frame.size.w * 0.01f;
	}
	return ComputeProperty(fv, e);
}

float ComputePropertyH(FloatValue fv, Element* e) {
	if (fv.unit == Property::Unit::PERCENT) {
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
