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
#include "../Include/RmlUi/ElementStyle.h"
#include <yoga/YGNodePrint.h>

namespace Rml {

static int YogaLogger(YGConfigRef config, YGNodeRef node, YGLogLevel level, const char* format, va_list args) {
	return vprintf(format, args);
}

static YGConfigRef createDefaultYogaConfig() {
	YGConfigRef config = YGConfigNew();
	YGConfigSetLogger(config, YogaLogger);
	return config;
}

static YGConfigRef DefaultYogaConfig() {
	static YGConfigRef config = createDefaultYogaConfig();
	return config;
}

Layout::Layout()
: node(YGNodeNewWithConfig(DefaultYogaConfig()))
{ }

Layout::~Layout() {
	YGNodeFree(node);
}

static float YGValueToFloat(float v) {
	if (YGFloatIsUndefined(v)) {
		return 0.0f;
	}
	return v;
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
#ifdef DEBUG
	auto options = static_cast<YGPrintOptions>(YGPrintOptionsLayout | YGPrintOptionsStyle | YGPrintOptionsChildren);
	facebook::yoga::YGNodeToString(result, node, options, 0);
#endif
	return result;
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

void Layout::SetProperty(PropertyId id, const Property* property, Element* element) {
	switch (property->unit) {
	case PropertyUnit::PERCENT:
		SetPercentProperty(node, id, property->GetFloat());
		break;
	case PropertyUnit::KEYWORD:
		SetIntProperty(node, id, property->GetKeyword());
		break;
	default:
		SetFloatProperty(node, id, ComputeProperty(property, element));
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

bool Layout::IsDirty() {
	return YGNodeIsDirty(node);
}

void Layout::MarkDirty() {
	YGNodeMarkDirty(node);
}

bool Layout::HasNewLayout() const {
	return YGNodeGetHasNewLayout(node);
}

bool Layout::UpdateVisible(Layout::Metrics& metrics) {
	metrics.visible = YGNodeStyleGetDisplay(node) != YGDisplayNone;
	if (!metrics.visible) {
		YGNodeSetHasNewLayout(node, false);
		return false;
	}
	return true;
}

void Layout::UpdateMetrics(Layout::Metrics& metrics, Rect& child) {
	metrics.frame = Rect{
		Point {
			YGValueToFloat(YGNodeLayoutGetLeft(node)),
			YGValueToFloat(YGNodeLayoutGetTop(node))
		},
		Size {
			YGValueToFloat(YGNodeLayoutGetWidth(node)),
			YGValueToFloat(YGNodeLayoutGetHeight(node))
		}
	};
	metrics.borderWidth = {
		YGValueToFloat(YGNodeLayoutGetBorder(node, YGEdgeLeft)),
		YGValueToFloat(YGNodeLayoutGetBorder(node, YGEdgeTop)),
		YGValueToFloat(YGNodeLayoutGetBorder(node, YGEdgeRight)),
		YGValueToFloat(YGNodeLayoutGetBorder(node, YGEdgeBottom))
	};
	metrics.paddingWidth = {
		YGValueToFloat(YGNodeLayoutGetPadding(node, YGEdgeLeft)),
		YGValueToFloat(YGNodeLayoutGetPadding(node, YGEdgeTop)),
		YGValueToFloat(YGNodeLayoutGetPadding(node, YGEdgeRight)),
		YGValueToFloat(YGNodeLayoutGetPadding(node, YGEdgeBottom))
	};
	Rect r = metrics.frame;
	r.Union(child);
	metrics.content = r;
	YGNodeSetHasNewLayout(node, false);
}

template <typename T>
void clamp(T& v, T min, T max) {
	assert(min <= max);
	if (v < min) {
		v = min;
	}
	else if (v > max) {
		v = max;
	}
}

void clamp(Size& s, Rect r) {
	clamp(s.w, r.left(), r.right());
	clamp(s.h, r.top(), r.bottom());
}

void Layout::UpdateScrollOffset(Size& scrollOffset, Layout::Metrics const& metrics) const {
	clamp(scrollOffset, metrics.content + metrics.scrollInsets - EdgeInsets<float> {0, 0, metrics.frame.size.w, metrics.frame.size.h});
}

Layout::Overflow Layout::GetOverflow() const {
	return (Layout::Overflow)YGNodeStyleGetOverflow(node);
}

void Layout::SetVisible(bool visible) {
	if (visible) {
		YGNodeStyleSetDisplay(node, YGDisplayFlex);
	}
	else {
		YGNodeStyleSetDisplay(node, YGDisplayNone);
	}
}

}
