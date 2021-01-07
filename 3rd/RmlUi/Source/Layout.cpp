/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2008-2010 CodePoint Ltd, Shift Technology Ltd
 * Copyright (c) 2019 The RmlUi Team, and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#include "../Include/RmlUi/Layout.h"
#include "../Include/RmlUi/ID.h"
#include "../Include/RmlUi/Property.h"
#include "../Include/RmlUi/ElementText.h"

#define DEBUG
#include <yoga/YGNodePrint.h>
#undef DEBUG

namespace Rml {

Layout::Layout()
: node(YGNodeNew())
{}

Layout::~Layout() {
	YGNodeFree(node);
}

static float YGValueToFloat(YGValue v) {
	if (v.unit == YGUnitUndefined) {
		return 0.0f;
	}
	return v.value;
}

static float YGValueToFloat(float v) {
	if (YGFloatIsUndefined(v)) {
		return 0.0f;
	}
	return v;
}

Size Layout::GetPaddingSize() const {
	Size size = GetSize();
	return size - Size(
		YGValueToFloat(YGNodeStyleGetBorder(node, YGEdgeLeft)) + YGValueToFloat(YGNodeStyleGetBorder(node, YGEdgeRight)),
		YGValueToFloat(YGNodeStyleGetBorder(node, YGEdgeTop)) + YGValueToFloat(YGNodeStyleGetBorder(node, YGEdgeBottom))
	);
}

Size Layout::GetContentSize() const {
	Size size = GetPaddingSize();
	return size - Size(
		YGValueToFloat(YGNodeStyleGetPadding(node, YGEdgeLeft)) + YGValueToFloat(YGNodeStyleGetPadding(node, YGEdgeRight)),
		YGValueToFloat(YGNodeStyleGetPadding(node, YGEdgeTop)) + YGValueToFloat(YGNodeStyleGetPadding(node, YGEdgeBottom))
	);
}

Size Layout::GetSize() const {
	return Size(
		YGNodeLayoutGetWidth(node),
		YGNodeLayoutGetHeight(node)
	);
}

Point Layout::GetOffset() const {
	return Point(
		YGNodeLayoutGetLeft(node),
		YGNodeLayoutGetTop(node)
	);
}

void Layout::SetWidth(float v) {
	YGNodeStyleSetWidth(node, v);
}

void Layout::SetHeight(float v) {
	YGNodeStyleSetHeight(node, v);
}

static YGEdge ConvertEdge(Layout::Edge edge) {
	switch (edge) {
	case Layout::Edge::LEFT: return YGEdgeLeft;
	case Layout::Edge::RIGHT: return YGEdgeRight;
	case Layout::Edge::TOP: return YGEdgeTop;
	case Layout::Edge::BOTTOM: return YGEdgeBottom;
	default: assert(false); return YGEdgeAll;
	}
}

float Layout::GetEdge(Area area, Edge edge) const {
	switch (area) {
	case Layout::Area::Margin:
		return YGValueToFloat(YGNodeStyleGetMargin(node, ConvertEdge(edge)));
	case Layout::Area::Border:
		return YGValueToFloat(YGNodeStyleGetBorder(node, ConvertEdge(edge)));
	case Layout::Area::Padding:
		return YGValueToFloat(YGNodeStyleGetPadding(node, ConvertEdge(edge)));
	default:
		return 0.0f;
	}
}

void Layout::CalculateLayout(Size const& size) {
	YGNodeCalculateLayout(node, size.w, size.h, YGDirectionLTR);
}

void Layout::InsertChild(Layout const& child, uint32_t index) {
	YGNodeInsertChild(node, child.node, index);
}

void Layout::SwapChild(Layout const& child, uint32_t index) {
	YGNodeSwapChild(node, child.node, index);
}

void Layout::RemoveChild(Layout const& child) {
	YGNodeRemoveChild(node, child.node);
}

void Layout::RemoveAllChildren() {
	YGNodeRemoveAllChildren(node);
}

std::string Layout::ToString() const {
	std::string result;
	auto options = static_cast<YGPrintOptions>(YGPrintOptionsLayout | YGPrintOptionsStyle | YGPrintOptionsChildren);
	facebook::yoga::YGNodeToString(result, node, options, 0);
	return result;
}

static float GetPropertyValue(const Property* property, float font_size, float document_font_size, float dp_ratio) {
	static constexpr float PixelsPerInch = 96.0f;
	float v = property->Get<float>();
	switch (property->unit) {
	case Property::PERCENT:
	case Property::NUMBER:
	case Property::PX:
	case Property::RAD:
		return v;
	case Property::DP:
		return v * dp_ratio;
	case Property::EM:
		return v * font_size;
	case Property::REM:
		return v * document_font_size;
	case Property::DEG:
		return Math::DegreesToRadians(v);
	case Property::INCH:
		return v * PixelsPerInch;
	case Property::CM:
		return v * PixelsPerInch * (1.0f / 2.54f);
	case Property::MM:
		return v * PixelsPerInch * (1.0f / 25.4f);
	case Property::PT:
		return v * PixelsPerInch * (1.0f / 72.0f);
	case Property::PC:
		return v * PixelsPerInch * (1.0f / 6.0f);
	default:
		break;
	}
	return 0.0f;
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

static void SetIntProperty(YGNodeRef node, PropertyId id, int v) {
	switch (id) {
	case PropertyId::MarginLeft:     YGNodeStyleSetMarginAuto(node, YGEdgeLeft); break;
	case PropertyId::MarginTop:      YGNodeStyleSetMarginAuto(node, YGEdgeTop); break;
	case PropertyId::MarginRight:    YGNodeStyleSetMarginAuto(node, YGEdgeRight); break;
	case PropertyId::MarginBottom:   YGNodeStyleSetMarginAuto(node, YGEdgeBottom); break;
	case PropertyId::Height:         YGNodeStyleSetHeightAuto(node); break;
	case PropertyId::Width:          YGNodeStyleSetWidthAuto(node); break;
	case PropertyId::Position:       YGNodeStyleSetPositionType(node, (YGPositionType)v); break;
	case PropertyId::Display:        YGNodeStyleSetDisplay(node, (YGDisplay)v); break;
	case PropertyId::Overflow:       YGNodeStyleSetOverflow(node, (YGOverflow)v); break;
	case PropertyId::AlignContent:   YGNodeStyleSetAlignContent(node, (YGAlign)v); break;
	case PropertyId::AlignItems:     YGNodeStyleSetAlignItems(node, (YGAlign)v); break;
	case PropertyId::AlignSelf:      YGNodeStyleSetAlignSelf(node, (YGAlign)v); break;
	case PropertyId::Direction:      YGNodeStyleSetDirection(node, (YGDirection)v); break;
	case PropertyId::FlexDirection:  YGNodeStyleSetFlexDirection(node, (YGFlexDirection)v); break;
	case PropertyId::FlexWrap:       YGNodeStyleSetFlexWrap(node, (YGWrap)v); break;
	case PropertyId::JustifyContent: YGNodeStyleSetJustifyContent(node, (YGJustify)v); break;
	case PropertyId::FlexBasis:      YGNodeStyleSetFlexBasisAuto(node); break;
	default: break;
	}
}

void Layout::SetProperty(PropertyId id, const Property* property, float font_size, float document_font_size, float dp_ratio) {
	switch (property->unit) {
	case Property::PERCENT:
		SetPercentProperty(node, id, property->Get<float>());
		break;
	case Property::KEYWORD:
		SetIntProperty(node, id, property->Get<int>());
		break;
	default:
		SetFloatProperty(node, id, GetPropertyValue(property, font_size, document_font_size, dp_ratio));
		break;
	}
}

static YGSize MeasureFunc(YGNodeRef node, float width, YGMeasureMode widthMode, float height, YGMeasureMode heightMode) {
	auto* element = static_cast<ElementText*>(YGNodeGetContext(node));
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
	}
	Size size = element->Measure(minWidth, maxWidth, minHeight, maxHeight);
	return { size.w, size.h };
}

static float BaselineFunc(YGNodeRef node, float width, float height) {
	auto* element = static_cast<ElementText*>(YGNodeGetContext(node));
	return element->GetBaseline();
}

void Layout::SetElementText(ElementText* element) {
	YGNodeSetContext(node, element);
	YGNodeSetMeasureFunc(node, MeasureFunc);
	YGNodeSetIsReferenceBaseline(node, true);
	YGNodeSetBaselineFunc(node, BaselineFunc);
}

void Layout::MarkDirty() {
	if (YGNodeGetContext(node)) {
		YGNodeMarkDirty(node);
	}
}

}
