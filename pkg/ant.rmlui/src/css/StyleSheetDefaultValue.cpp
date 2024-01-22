#include <css/StyleSheetDefaultValue.h>
#include <css/StyleCache.h>
#include <css/StyleSheetSpecification.h>
#include <css/EnumName.h>
#include <core/ID.h>
#include <util/Log.h>

namespace Rml {

static constexpr std::pair<PropertyId, std::string_view> UnparsedDefaultValue[] = {
	{ PropertyId::BorderTopWidth, "0px" },
	{ PropertyId::BorderRightWidth, "0px" },
	{ PropertyId::BorderBottomWidth, "0px" },
	{ PropertyId::BorderLeftWidth, "0px" },
	{ PropertyId::BorderTopColor, "transparent" },
	{ PropertyId::BorderRightColor, "transparent" },
	{ PropertyId::BorderBottomColor, "transparent" },
	{ PropertyId::BorderLeftColor, "transparent" },
	{ PropertyId::BorderTopLeftRadius, "0px" },
	{ PropertyId::BorderTopRightRadius, "0px" },
	{ PropertyId::BorderBottomRightRadius, "0px" },
	{ PropertyId::BorderBottomLeftRadius, "0px" },
	{ PropertyId::ZIndex, "0" },
	{ PropertyId::LineHeight, "normal" },
	{ PropertyId::Color, "white" },
	{ PropertyId::Opacity, "1" },
	{ PropertyId::FontFamily, "" },
	{ PropertyId::FontStyle, "normal" },
	{ PropertyId::FontWeight, "normal" },
	{ PropertyId::FontSize, "12px" },
	{ PropertyId::TextAlign, "left" },
	{ PropertyId::WordBreak, "normal" },
	{ PropertyId::TextDecorationLine, "none" },
	{ PropertyId::TextDecorationColor, "currentColor" },
	{ PropertyId::Perspective, "none" },
	{ PropertyId::PerspectiveOriginX, "50%" },
	{ PropertyId::PerspectiveOriginY, "50%" },
	{ PropertyId::Transform, "none" },
	{ PropertyId::TransformOriginX, "50%" },
	{ PropertyId::TransformOriginY, "50%" },
	{ PropertyId::TransformOriginZ, "0px" },
	{ PropertyId::Transition, "none" },
	{ PropertyId::BackgroundColor, "transparent" },
	{ PropertyId::BackgroundImage, "none" },
	{ PropertyId::BackgroundOrigin, "padding-box" },
	{ PropertyId::BackgroundSize, "unset" },
	{ PropertyId::BackgroundSizeX, "0px" },
	{ PropertyId::BackgroundSizeY, "0px" },
	{ PropertyId::BackgroundPositionX, "0px" },
	{ PropertyId::BackgroundPositionY, "0px" },
	{ PropertyId::BackgroundLattice, "auto" },
	{ PropertyId::BackgroundLatticeX1, "0px" },
	{ PropertyId::BackgroundLatticeY1, "0px" },
	{ PropertyId::BackgroundLatticeX2, "0px" },
	{ PropertyId::BackgroundLatticeY2, "0px" },
	{ PropertyId::BackgroundLatticeU, "0px" },
	{ PropertyId::BackgroundLatticeV, "0px" },
	//{ PropertyId::BackgroundRepeat, "repeat" },
	{ PropertyId::BackgroundFilter, "none" },
	{ PropertyId::TextShadowH, "0px" },
	{ PropertyId::TextShadowV, "0px" },
	{ PropertyId::TextShadowColor, "white" },
	{ PropertyId::_WebkitTextStrokeWidth, "0px" },
	{ PropertyId::_WebkitTextStrokeColor, "white" },
	{ PropertyId::OutlineWidth, "0px" },
	{ PropertyId::OutlineColor, "white" },
	{ PropertyId::PointerEvents, "auto" },
	{ PropertyId::ScrollLeft, "0px" },
	{ PropertyId::ScrollTop, "0px" },
	{ PropertyId::Filter, "none" },
};

static Style::TableRef DefaultValueProperties;

void StyleSheetDefaultValue::Initialise() {
	PropertyVector properties;
	for (auto const& [id, value] : UnparsedDefaultValue) {
		if (!StyleSheetSpecification::ParseDeclaration(properties, id, value)) {
			auto prop_name = GetCssEnumName<CssEnumNameStyle::Kebab>(id);
			Log::Message(Log::Level::Error, "property '%s' default value (%s) parse failed..", prop_name.data(), value.data());
		}
	}
	DefaultValueProperties = Style::Instance().Create(properties);
}

void StyleSheetDefaultValue::Shutdown() {
	DefaultValueProperties = {};
}

const Style::TableRef& StyleSheetDefaultValue::Get() {
	return DefaultValueProperties;
}

}
