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

#include "ElementBackgroundImage.h"
#include "ElementDefinition.h"
#include "../Include/RmlUi/Texture.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/Geometry.h"
#include "../Include/RmlUi/Document.h"
#include "../Include/RmlUi/SystemInterface.h"
#include "../Include/RmlUi/Core.h"

namespace Rml {

void ElementBackgroundImage::GenerateGeometry(Element* element, Geometry& geometry, Geometry::Path const& paddingEdge) {
	geometry.Release();

	Layout::Metrics const& metrics = element->GetMetrics();
	Rect surface = Rect{ {0, 0}, metrics.frame.size } - metrics.borderWidth;
	if (surface.size.IsEmpty()) {
		return;
	}
	const Property* image = element->GetProperty(PropertyId::BackgroundImage);
	if (image->unit != Property::STRING) {
		// "none"
		return;
	}

	Style::BoxType origin = (Style::BoxType)element->GetProperty(PropertyId::BackgroundOrigin)->Get<int>();
	Style::BackgroundSize size = (Style::BackgroundSize)element->GetProperty(PropertyId::BackgroundSize)->Get<int>();

	String path;
	GetSystemInterface()->JoinPath(path, StringUtilities::Replace(element->GetOwnerDocument()->GetSourceURL(), '|', ':'), image->Get<String>());
	auto texture = Texture::Fetch(path);
	geometry.SetTexture(texture);
	Color colour(255, 255, 255, 255);
	ColorApplyOpacity(colour, element->GetOpacity());

	Rect tex{ {}, texture->GetDimensions() };
	Size scale{
		surface.size.w / tex.size.w,
		surface.size.h / tex.size.h
	};
	float aspectRatio = scale.w / scale.h;
	Rect uv;
	switch (size) {
	case Style::BackgroundSize::Auto:
		uv.size.w = scale.w;
		uv.size.h = scale.h;
		break;
	case Style::BackgroundSize::Contain:
		if (aspectRatio < 1.f) {
			uv.size.w = 1.f;
			uv.size.h = 1.f / aspectRatio;
		}
		else {
			uv.size.w = aspectRatio;
			uv.size.h = 1.f;
		}
		break;
	case Style::BackgroundSize::Cover:
		if (aspectRatio > 1.f) {
			uv.size.w = 1.f;
			uv.size.h = 1.f / aspectRatio;
		}
		else {
			uv.size.w = aspectRatio;
			uv.size.h = 1.f;
		}
		break;
	}

	switch (origin) {
	case Style::BoxType::PaddingBox:
	case Style::BoxType::BorderBox:
	case Style::BoxType::ContentBox:
		break;
	}

	if (paddingEdge.size() == 0) {
		geometry.AddRect(surface, colour);
		geometry.UpdateUV(4, surface, uv);
	}
	else {
		geometry.AddPolygon(paddingEdge, colour);
		geometry.UpdateUV(paddingEdge.size(), surface, uv);
	}
}

} // namespace Rml
