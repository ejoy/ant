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

#include "ElementBackgroundBorder.h"
#include "../Include/RmlUi/Layout.h"
#include "../Include/RmlUi/ComputedValues.h"
#include "../Include/RmlUi/Element.h"

namespace Rml {

static const auto PI = std::acosf(-1);

void ElementBackgroundBorder::GenerateGeometry(Element* element, Geometry& geometry, Geometry::Path& paddingEdge) {
	geometry.Release();
	const ComputedValues& computed = element->GetComputedValues();
	const float opacity = computed.opacity;
	EdgeInsets<Colourb> border_color = computed.border_color;
	Colourb background_color = computed.background_color;
	if (opacity < 1) {
		background_color.alpha = (byte)(opacity * (float)background_color.alpha);
		for (int i = 0; i < 4; ++i) {
			border_color[i].alpha = (byte)(opacity * (float)border_color[i].alpha);
		}
	}

	geometry.GetVertices().clear();
	geometry.GetIndices().clear();
	const Layout::Metrics& metrics = element->GetMetrics();

	Rect padding = metrics.frame - metrics.borderWidth;
	Quad quadLeft = {
		{ 0, computed.border_radius.topLeft },
		{ metrics.borderWidth.left, std::max(metrics.borderWidth.top, computed.border_radius.topLeft) },
		{ metrics.borderWidth.left, metrics.frame.size.h - std::max(metrics.borderWidth.bottom, computed.border_radius.bottomLeft) },
		{ 0, metrics.frame.size.h - computed.border_radius.bottomLeft }
	};
	Quad quadTop = {
		{ computed.border_radius.topLeft, 0 },
		{ metrics.frame.size.w - computed.border_radius.topRight, 0 },
		{ metrics.frame.size.w - std::max(metrics.borderWidth.right, computed.border_radius.topRight), metrics.borderWidth.top },
		{ std::max(metrics.borderWidth.left, computed.border_radius.topLeft), metrics.borderWidth.top },
	};
	Quad quadRight = {
		{ metrics.frame.size.w - metrics.borderWidth.right, std::max(metrics.borderWidth.top, computed.border_radius.topRight) },
		{ metrics.frame.size.w, computed.border_radius.topRight },
		{ metrics.frame.size.w, metrics.frame.size.h - computed.border_radius.bottomRight },
		{ metrics.frame.size.w - metrics.borderWidth.right, metrics.frame.size.h - std::max(metrics.borderWidth.bottom, computed.border_radius.bottomRight) },
	};
	Quad quadBottom = {
		{ std::max(metrics.borderWidth.left, computed.border_radius.bottomLeft), metrics.frame.size.h - metrics.borderWidth.bottom },
		{ metrics.frame.size.w - std::max(metrics.borderWidth.right, computed.border_radius.bottomRight), metrics.frame.size.h - metrics.borderWidth.bottom },
		{ metrics.frame.size.w - computed.border_radius.bottomRight, metrics.frame.size.h },
		{ computed.border_radius.bottomLeft, metrics.frame.size.h },
	};

	geometry.AddQuad(quadLeft, computed.border_color.left);
	Geometry::Path topLeftOuter;
	topLeftOuter.DrawArc(
		{ computed.border_radius.topLeft, computed.border_radius.topLeft },
		computed.border_radius.topLeft,
		computed.border_radius.topLeft,
		PI, PI * 1.5f
	);
	Geometry::Path topLeftInner;
	topLeftInner.DrawArc(
		{ computed.border_radius.topLeft, computed.border_radius.topLeft },
		std::max(0.0f, computed.border_radius.topLeft - metrics.borderWidth.left),
		std::max(0.0f, computed.border_radius.topLeft - metrics.borderWidth.top),
		PI, PI * 1.5f
	);
	geometry.AddArc(topLeftOuter, topLeftInner, computed.border_color.left);

	geometry.AddQuad(quadTop, computed.border_color.top);
	Geometry::Path topRightOuter;
	topRightOuter.DrawArc(
		{ metrics.frame.size.w - computed.border_radius.topRight, computed.border_radius.topRight },
		computed.border_radius.topRight,
		computed.border_radius.topRight,
		PI * 1.5f, PI * 2.f
	);
	Geometry::Path topRightInner;
	topRightInner.DrawArc(
		{ metrics.frame.size.w - computed.border_radius.topRight, computed.border_radius.topRight },
		std::max(0.0f, computed.border_radius.topRight - metrics.borderWidth.right),
		std::max(0.0f, computed.border_radius.topRight - metrics.borderWidth.top),
		PI * 1.5f, PI * 2.f
	);
	geometry.AddArc(topRightOuter, topRightInner, computed.border_color.top);

	geometry.AddQuad(quadRight, computed.border_color.right);
	Geometry::Path bottomRightOuter;
	bottomRightOuter.DrawArc(
		{ metrics.frame.size.w - computed.border_radius.bottomRight, metrics.frame.size.h - computed.border_radius.bottomRight },
		computed.border_radius.bottomRight,
		computed.border_radius.bottomRight,
		0, PI * 0.5f
	);
	Geometry::Path bottomRightInner;
	bottomRightInner.DrawArc(
		{ metrics.frame.size.w - computed.border_radius.bottomRight, metrics.frame.size.h - computed.border_radius.bottomRight },
		std::max(0.0f, computed.border_radius.bottomRight - metrics.borderWidth.right),
		std::max(0.0f, computed.border_radius.bottomRight - metrics.borderWidth.bottom),
		0, PI * 0.5f
	);
	geometry.AddArc(bottomRightOuter, bottomRightInner, computed.border_color.right);

	geometry.AddQuad(quadBottom, computed.border_color.bottom);
	Geometry::Path bottomLeftOuter;
	bottomLeftOuter.DrawArc(
		{ computed.border_radius.bottomLeft, metrics.frame.size.h - computed.border_radius.bottomLeft },
		computed.border_radius.bottomLeft,
		computed.border_radius.bottomLeft,
		PI * 0.5f, PI
	);
	Geometry::Path bottomLeftInner;
	bottomLeftInner.DrawArc(
		{ computed.border_radius.bottomLeft, metrics.frame.size.h - computed.border_radius.bottomLeft },
		std::max(0.0f, computed.border_radius.bottomLeft - metrics.borderWidth.left),
		std::max(0.0f, computed.border_radius.bottomLeft - metrics.borderWidth.bottom),
		PI * 0.5f, PI
	);
	geometry.AddArc(bottomLeftOuter, bottomLeftInner, computed.border_color.bottom);

	paddingEdge.clear();
	paddingEdge.append(topLeftInner);
	paddingEdge.append(topRightInner);
	paddingEdge.append(bottomRightInner);
	paddingEdge.append(bottomLeftInner);
	geometry.AddPolygon(paddingEdge, background_color);
}

} // namespace Rml
