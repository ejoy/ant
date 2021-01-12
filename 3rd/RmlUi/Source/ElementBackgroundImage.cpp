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
#include "../Include/RmlUi/ElementDocument.h"
#include "../Include/RmlUi/GeometryUtilities.h"
#include "../Include/RmlUi/SystemInterface.h"
#include "../Include/RmlUi/Core.h"

namespace Rml {

ElementBackgroundImage::ElementBackgroundImage(Element* _element)
: element(_element)
{ }

ElementBackgroundImage::~ElementBackgroundImage() {
}

void ElementBackgroundImage::Reload() {
	geometry.reset();

	auto& background_image = element->GetComputedValues().background_image;
	if (background_image.empty() || background_image == "auto") {
		return;
	}	
	String path;
	if (background_image.size() > 0 && background_image[0] == '?')
		path = background_image;
	else
		GetSystemInterface()->JoinPath(path, StringUtilities::Replace(element->GetOwnerDocument()->GetSourceURL(), '|', ':'), background_image);

	geometry.reset(new Geometry());
	geometry->SetTexture(Texture::Fetch(path));

	Layout::Metrics const& metrics = element->GetMetrics();
	const auto& computed = element->GetComputedValues();
	Colourb quad_colour(255, 255, 255, byte(255 * computed.opacity));
	GeometryUtilities::GenerateRect(
		*geometry,
		Rect{
			Point(0, 0),
			metrics.frame.size - metrics.borderWidth
		},
		quad_colour,
		Rect{ 0,0,1,1 }
	);
}

void ElementBackgroundImage::Render() {
	if (dirty) {
		dirty = false;
		Reload();
	}
	if (geometry) {
		geometry->Render(element->GetOffset() + element->GetMetrics().borderWidth);
	}
}

void ElementBackgroundImage::MarkDirty() {
	dirty = true;
}

} // namespace Rml
