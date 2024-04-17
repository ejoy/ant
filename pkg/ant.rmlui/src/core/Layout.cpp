#include <core/Layout.h>
#include <core/ID.h>
#include <css/Property.h>
#include <core/Text.h>
#include <yoga/Yoga.h>
#include <bee/nonstd/unreachable.h>

namespace Rml {

struct DefaultConfig {
	DefaultConfig()
		: config(YGConfigNew()) {
		YGConfigSetPointScaleFactor(config, 0);
		YGConfigSetErrata(config, YGErrataNone
			| YGErrataAbsolutePositioningIncorrect
			);
	}
	~DefaultConfig() {
		YGConfigFree(config);
	}
	YGConfigRef config;
};

static YGConfigConstRef GetDefaultConfig() {
	static DefaultConfig def;
	return def.config;
}

static YGSize MeasureFunc(YGNodeConstRef node, float width, YGMeasureMode widthMode, float height, YGMeasureMode heightMode) {
	auto* element = static_cast<Text*>(YGNodeGetContext(node));
	float minWidth = 0;
	float maxWidth = std::numeric_limits<float>::max();
	float minHeight = 0;
	float maxHeight = std::numeric_limits<float>::max();
	switch (widthMode) {
	case YGMeasureModeUndefined:
		break;
	case YGMeasureModeExactly:
		minWidth = width;
		maxWidth = width;
		break;
	case YGMeasureModeAtMost:
		maxWidth = width;
		break;
	default:
		std::unreachable();
	}
	switch (heightMode) {
	case YGMeasureModeUndefined:
		break;
	case YGMeasureModeExactly:
		minHeight = height;
		maxHeight = height;
		break;
	case YGMeasureModeAtMost:
		maxHeight = height;
		break;
	default:
		std::unreachable();
	}
	Size size = element->Measure(minWidth, maxWidth, minHeight, maxHeight);
	return { size.w, size.h };
}

static float BaselineFunc(YGNodeConstRef node, float width, float height) {
	auto* element = static_cast<Text*>(YGNodeGetContext(node));
	return element->GetBaseline();
}

Layout::Layout(UseElement)
: node(YGNodeNewWithConfig(GetDefaultConfig()))
{ }

Layout::Layout(UseText, void* context)
: node(YGNodeNewWithConfig(GetDefaultConfig()))
{
	YGNodeSetContext(node, context);
	YGNodeSetMeasureFunc(node, MeasureFunc);
	YGNodeSetIsReferenceBaseline(node, true);
	YGNodeSetBaselineFunc(node, BaselineFunc);
}

Layout::~Layout() {
	YGNodeFree(node);
}

float Layout::YGValueToFloat(float v) const {
	if (YGFloatIsUndefined(v)) {
		return 0.0f;
	}
	return v;
}

void Layout::CalculateLayout(Size const& size) {
	YGNodeCalculateLayout(node, size.w, size.h, YGDirectionLTR);
}

void Layout::InsertChild(Layout const& child, size_t index) {
	YGNodeInsertChild(node, child.node, index);
}

void Layout::RemoveChild(Layout const& child) {
	YGNodeRemoveChild(node, child.node);
}

void Layout::RemoveAllChildren() {
	YGNodeRemoveAllChildren(node);
}

static void SetFloatProperty(YGNodeRef node, PropertyId id, float v) {
	switch (id) {
	case PropertyId::Left:              YGNodeStyleSetPosition(node, YGEdgeLeft, v); break;
	case PropertyId::Top:               YGNodeStyleSetPosition(node, YGEdgeTop, v); break;
	case PropertyId::Right:             YGNodeStyleSetPosition(node, YGEdgeRight, v); break;
	case PropertyId::Bottom:            YGNodeStyleSetPosition(node, YGEdgeBottom, v); break;
	case PropertyId::MarginLeft:        YGNodeStyleSetMargin(node, YGEdgeLeft, v); break;
	case PropertyId::MarginTop:         YGNodeStyleSetMargin(node, YGEdgeTop, v); break;
	case PropertyId::MarginRight:       YGNodeStyleSetMargin(node, YGEdgeRight, v); break;
	case PropertyId::MarginBottom:      YGNodeStyleSetMargin(node, YGEdgeBottom, v); break;
	case PropertyId::PaddingLeft:       YGNodeStyleSetPadding(node, YGEdgeLeft, v); break;
	case PropertyId::PaddingTop:        YGNodeStyleSetPadding(node, YGEdgeTop, v); break;
	case PropertyId::PaddingRight:      YGNodeStyleSetPadding(node, YGEdgeRight, v); break;
	case PropertyId::PaddingBottom:     YGNodeStyleSetPadding(node, YGEdgeBottom, v); break;
	case PropertyId::BorderLeftWidth:   YGNodeStyleSetBorder(node, YGEdgeLeft, v); break;
	case PropertyId::BorderTopWidth:    YGNodeStyleSetBorder(node, YGEdgeTop, v); break;
	case PropertyId::BorderRightWidth:  YGNodeStyleSetBorder(node, YGEdgeRight, v); break;
	case PropertyId::BorderBottomWidth: YGNodeStyleSetBorder(node, YGEdgeBottom, v); break;
	case PropertyId::ColumnGap:         YGNodeStyleSetGap(node, YGGutterColumn, v); break;
	case PropertyId::RowGap:            YGNodeStyleSetGap(node, YGGutterRow, v); break;
	case PropertyId::Gap:               YGNodeStyleSetGap(node, YGGutterAll, v); break;
	case PropertyId::Height:            YGNodeStyleSetHeight(node, v); break;
	case PropertyId::Width:             YGNodeStyleSetWidth(node, v); break;
	case PropertyId::MaxHeight:         YGNodeStyleSetMaxHeight(node, v); break;
	case PropertyId::MinHeight:         YGNodeStyleSetMinHeight(node, v); break;
	case PropertyId::MaxWidth:          YGNodeStyleSetMaxWidth(node, v); break;
	case PropertyId::MinWidth:          YGNodeStyleSetMinWidth(node, v); break;
	case PropertyId::AspectRatio:       YGNodeStyleSetAspectRatio(node, v); break;
	case PropertyId::Flex:              YGNodeStyleSetFlex(node, v); break;
	case PropertyId::FlexBasis:         YGNodeStyleSetFlexBasis(node, v); break;
	case PropertyId::FlexGrow:          YGNodeStyleSetFlexGrow(node, v); break;
	case PropertyId::FlexShrink:        YGNodeStyleSetFlexShrink(node, v); break;
	default: break;
	}
}

static void SetPercentProperty(YGNodeRef node, PropertyId id, float v) {
	switch (id) {
	case PropertyId::Left:          YGNodeStyleSetPositionPercent(node, YGEdgeLeft, v); break;
	case PropertyId::Top:           YGNodeStyleSetPositionPercent(node, YGEdgeTop, v); break;
	case PropertyId::Right:         YGNodeStyleSetPositionPercent(node, YGEdgeRight, v); break;
	case PropertyId::Bottom:        YGNodeStyleSetPositionPercent(node, YGEdgeBottom, v); break;
	case PropertyId::MarginLeft:    YGNodeStyleSetMarginPercent(node, YGEdgeLeft, v); break;
	case PropertyId::MarginTop:     YGNodeStyleSetMarginPercent(node, YGEdgeTop, v); break;
	case PropertyId::MarginRight:   YGNodeStyleSetMarginPercent(node, YGEdgeRight, v); break;
	case PropertyId::MarginBottom:  YGNodeStyleSetMarginPercent(node, YGEdgeBottom, v); break;
	case PropertyId::PaddingLeft:   YGNodeStyleSetPaddingPercent(node, YGEdgeLeft, v); break;
	case PropertyId::PaddingTop:    YGNodeStyleSetPaddingPercent(node, YGEdgeTop, v); break;
	case PropertyId::PaddingRight:  YGNodeStyleSetPaddingPercent(node, YGEdgeRight, v); break;
	case PropertyId::PaddingBottom: YGNodeStyleSetPaddingPercent(node, YGEdgeBottom, v); break;
	case PropertyId::ColumnGap:     YGNodeStyleSetGapPercent(node, YGGutterColumn, v); break;
	case PropertyId::RowGap:        YGNodeStyleSetGapPercent(node, YGGutterRow, v); break;
	case PropertyId::Gap:           YGNodeStyleSetGapPercent(node, YGGutterAll, v); break;
	case PropertyId::Height:        YGNodeStyleSetHeightPercent(node, v); break;
	case PropertyId::Width:         YGNodeStyleSetWidthPercent(node, v); break;
	case PropertyId::MaxHeight:     YGNodeStyleSetMaxHeightPercent(node, v); break;
	case PropertyId::MinHeight:     YGNodeStyleSetMinHeightPercent(node, v); break;
	case PropertyId::MaxWidth:      YGNodeStyleSetMaxWidthPercent(node, v); break;
	case PropertyId::MinWidth:      YGNodeStyleSetMinWidthPercent(node, v); break;
	case PropertyId::FlexBasis:     YGNodeStyleSetFlexBasisPercent(node, v); break;
	default: break;
	}
}

static void SetIntProperty(YGNodeRef node, PropertyId id, const Property& prop) {
	switch (id) {
	case PropertyId::MarginLeft:     YGNodeStyleSetMarginAuto(node, YGEdgeLeft); break;
	case PropertyId::MarginTop:      YGNodeStyleSetMarginAuto(node, YGEdgeTop); break;
	case PropertyId::MarginRight:    YGNodeStyleSetMarginAuto(node, YGEdgeRight); break;
	case PropertyId::MarginBottom:   YGNodeStyleSetMarginAuto(node, YGEdgeBottom); break;
	case PropertyId::Height:         YGNodeStyleSetHeightAuto(node); break;
	case PropertyId::Width:          YGNodeStyleSetWidthAuto(node); break;
	case PropertyId::Position:       YGNodeStyleSetPositionType(node, prop.GetEnum<YGPositionType>()); break;
	case PropertyId::Display:        YGNodeStyleSetDisplay(node, prop.GetEnum<YGDisplay>()); break;
	case PropertyId::Overflow:       YGNodeStyleSetOverflow(node, prop.GetEnum<YGOverflow>()); break;
	case PropertyId::AlignContent:   YGNodeStyleSetAlignContent(node, prop.GetEnum<YGAlign>()); break;
	case PropertyId::AlignItems:     YGNodeStyleSetAlignItems(node, prop.GetEnum<YGAlign>()); break;
	case PropertyId::AlignSelf:      YGNodeStyleSetAlignSelf(node, prop.GetEnum<YGAlign>()); break;
	case PropertyId::Direction:      YGNodeStyleSetDirection(node, prop.GetEnum<YGDirection>()); break;
	case PropertyId::FlexDirection:  YGNodeStyleSetFlexDirection(node, prop.GetEnum<YGFlexDirection>()); break;
	case PropertyId::FlexWrap:       YGNodeStyleSetFlexWrap(node, prop.GetEnum<YGWrap>()); break;
	case PropertyId::JustifyContent: YGNodeStyleSetJustifyContent(node, prop.GetEnum<YGJustify>()); break;
	case PropertyId::FlexBasis:      YGNodeStyleSetFlexBasisAuto(node); break;
	default: break;
	}
}

void Layout::SetProperty(PropertyId id, const Property& prop, const Element* element) {
	if (prop.Has<PropertyKeyword>()) {
		SetIntProperty(node, id, prop);
		return;
	}
	auto const& fv = prop.Get<PropertyFloat>();
	if (fv.unit == PropertyUnit::PERCENT) {
		SetPercentProperty(node, id, fv.value);
	}
	else {
		SetFloatProperty(node, id, fv.Compute(element));
	}
}

bool Layout::IsDirty() const {
	return YGNodeIsDirty(node);
}

void Layout::MarkDirty() {
	YGNodeMarkDirty(node);
}

bool Layout::HasNewLayout() {
	if (!YGNodeGetHasNewLayout(node)) {
		return false;
	}
	YGNodeSetHasNewLayout(node, false);
	return true;
}

Layout::Overflow Layout::GetOverflow() const {
	return (Overflow)YGNodeStyleGetOverflow(node);
}

Layout::Type Layout::GetType() const {
	return (Type)YGNodeGetNodeType(node);
}

bool Layout::IsVisible() const {
	return YGNodeStyleGetDisplay(node) != YGDisplayNone;
}

void Layout::SetVisible(bool visible) {
	if (visible) {
		YGNodeStyleSetDisplay(node, YGDisplayFlex);
	}
	else {
		YGNodeStyleSetDisplay(node, YGDisplayNone);
	}
}

Rect Layout::GetBounds() const {
	return {
		Point {
			YGValueToFloat(YGNodeLayoutGetLeft(node)),
			YGValueToFloat(YGNodeLayoutGetTop(node))
		},
		Size {
			YGValueToFloat(YGNodeLayoutGetWidth(node)),
			YGValueToFloat(YGNodeLayoutGetHeight(node))
		}
	};
}

EdgeInsets<float> Layout::GetPadding() const {
	return {
		YGValueToFloat(YGNodeLayoutGetPadding(node, YGEdgeLeft)),
		YGValueToFloat(YGNodeLayoutGetPadding(node, YGEdgeTop)),
		YGValueToFloat(YGNodeLayoutGetPadding(node, YGEdgeRight)),
		YGValueToFloat(YGNodeLayoutGetPadding(node, YGEdgeBottom))
	};
}

EdgeInsets<float> Layout::GetBorder() const {
	return {
		YGValueToFloat(YGNodeLayoutGetBorder(node, YGEdgeLeft)),
		YGValueToFloat(YGNodeLayoutGetBorder(node, YGEdgeTop)),
		YGValueToFloat(YGNodeLayoutGetBorder(node, YGEdgeRight)),
		YGValueToFloat(YGNodeLayoutGetBorder(node, YGEdgeBottom))
	};
}

}
