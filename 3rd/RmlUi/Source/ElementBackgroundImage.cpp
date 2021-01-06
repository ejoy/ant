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
#include "../Include/RmlUi/Core.h"

namespace Rml {

struct Tile {
	enum Orientation {
		ORIENTATION_NONE,       // No orientation.
		FLIP_HORIZONTAL,        // Flipped horizontally.
		FLIP_VERTICAL,          // Flipped vertically.
		ROTATE_180,             // Rotated 180 degrees clockwise.
	};
	enum FitMode {
		FILL,       // Tile is stretched to boundaries.
		CONTAIN,    // Tile is stretched to boundaries, keeping aspect ratio fixed, 'letter-boxed'.
		COVER,      // Tile is stretched to cover the boundaries, keeping aspect ratio fixed.
		SCALE_NONE, // Tile is never scaled.
		SCALE_DOWN, // Tile acts like 'scale-none' if smaller than boundaries, or like 'contain' otherwise.
	};

	void GenerateGeometry(Vector<Vertex>& vertices, Vector<int>& indices, Element* element, const Texture& texture, const Vector2f& surface_origin, const Vector2f& surface_dimensions);

	Orientation orientation = ORIENTATION_NONE;
	FitMode fit_mode = CONTAIN;
	Style::LengthPercentage align[2];
};

	
static const Vector2f oriented_texcoords[4][2] = {
	{Vector2f(0, 0), Vector2f(1, 1)},   // ORIENTATION_NONE
	{Vector2f(1, 0), Vector2f(0, 1)},   // FLIP_HORIZONTAL
	{Vector2f(0, 1), Vector2f(1, 0)},   // FLIP_VERTICAL
	{Vector2f(1, 1), Vector2f(0, 0)}    // ROTATE_180
};

void Tile::GenerateGeometry(Vector<Vertex>& vertices, Vector<int>& indices, Element* element, const Texture& texture, const Vector2f& surface_origin, const Vector2f& surface_dimensions) {
	Vector2f position(0, 0);
	Vector2f size(0, 0);
	Vector2f tile_dimensions; // 'px' units
	Vector2f texcoords[2]; // relative units

	const Vector2i texture_dimensions_i = texture.GetDimensions();
	const Vector2f texture_dimensions((float)texture_dimensions_i.x, (float)texture_dimensions_i.y);
	if (texture_dimensions.x == 0 || texture_dimensions.y == 0) {
		tile_dimensions = Vector2f(0, 0);
		texcoords[0] = Vector2f(0, 0);
		texcoords[1] = Vector2f(0, 0);
	}
	else {
		if (size.x == 0 && size.y == 0 && position.x == 0 && position.y == 0)
			tile_dimensions = texture_dimensions;
		else
			tile_dimensions = size;
		Vector2f size_relative = tile_dimensions / texture_dimensions;
		tile_dimensions = Vector2f(Math::AbsoluteValue(tile_dimensions.x), Math::AbsoluteValue(tile_dimensions.y));
		texcoords[0] = position / texture_dimensions;
		texcoords[1] = size_relative + texcoords[0];
	}

	if (surface_dimensions.x <= 0 || surface_dimensions.y <= 0)
		return;

	const auto& computed = element->GetComputedValues();
	float opacity = computed.opacity;
	Colourb quad_colour = computed.image_color;
    quad_colour.alpha = (byte)(opacity * (float)quad_colour.alpha);
	Vector2f scaled_texcoords[2];
	for (int i = 0; i < 2; i++) {
		scaled_texcoords[i] = texcoords[0] + oriented_texcoords[orientation][i] * (texcoords[1] - texcoords[0]);
	}
	Vector2f final_tile_dimensions;
	bool offset_and_clip_tile = false;
	switch (fit_mode) {
	case FILL:
		final_tile_dimensions = surface_dimensions;
		break;
	case CONTAIN: {
		Vector2f scale_factor = surface_dimensions / tile_dimensions;
		float min_factor = std::min(scale_factor.x, scale_factor.y);
		final_tile_dimensions = tile_dimensions * min_factor;
		offset_and_clip_tile = true;
		break;
	}
	case COVER: {
		Vector2f scale_factor = surface_dimensions / tile_dimensions;
		float max_factor = std::max(scale_factor.x, scale_factor.y);
		final_tile_dimensions = tile_dimensions * max_factor;
		offset_and_clip_tile = true;
		break;
	}
	case SCALE_NONE:
		final_tile_dimensions = tile_dimensions;
		offset_and_clip_tile = true;
		break;
	case SCALE_DOWN: {
		Vector2f scale_factor = surface_dimensions / tile_dimensions;
		float min_factor = std::min(scale_factor.x, scale_factor.y);
		if (min_factor < 1.0f)
			final_tile_dimensions = tile_dimensions * min_factor;
		else
			final_tile_dimensions = tile_dimensions;
		offset_and_clip_tile = true;
		break;
	}
	}

	Vector2f tile_offset(0, 0);

	if (offset_and_clip_tile) {
		for(int i = 0; i < 2; i++) {
			switch (align[i].type) {
			case Style::LengthPercentage::Length:      tile_offset[i] = align[i].value;  break;
			case Style::LengthPercentage::Percentage:  tile_offset[i] = (surface_dimensions[i] - final_tile_dimensions[i]) * align[i].value * 0.01f;  break;
			}
		}
		tile_offset = tile_offset.Round();

		for(int i = 0; i < 2; i++) {
			float overshoot_left = std::max(-tile_offset[i], 0.0f);
			float overshoot_right = std::max(tile_offset[i] + final_tile_dimensions[i] - surface_dimensions[i], 0.0f);

			if(overshoot_left > 0.f || overshoot_right > 0.f) {
				float& left = scaled_texcoords[0][i];
				float& right = scaled_texcoords[1][i];
				float width = right - left;

				left += overshoot_left / final_tile_dimensions[i] * width;
				right -= overshoot_right / final_tile_dimensions[i] * width;

				final_tile_dimensions[i] -= overshoot_left + overshoot_right;
				tile_offset[i] += overshoot_left;
			}
		}
	}

	int index_offset = (int) vertices.size();
	vertices.resize(vertices.size() + 4);
	Vertex* new_vertices = &vertices[0] + index_offset;
	size_t num_indices = indices.size();
	indices.resize(indices.size() + 6);
	int* new_indices = &indices[0] + num_indices;
	Vector2f tile_position = (surface_origin + tile_offset).Round();
	GeometryUtilities::GenerateQuad(new_vertices, new_indices, tile_position, final_tile_dimensions.Round(), quad_colour, scaled_texcoords[0], scaled_texcoords[1], index_offset);
}

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
	texture.reset(new Texture);
	texture->Set(background_image, element->GetOwnerDocument()->GetSourceURL());

	geometry.reset(new Geometry());
	geometry->SetTexture(texture.get());

	Tile tile;
	tile.align[0] = Style::LengthPercentage(Style::LengthPercentage::Percentage, 0.0f);
	tile.align[1] = Style::LengthPercentage(Style::LengthPercentage::Percentage, 0.0f);
	tile.GenerateGeometry(
		geometry->GetVertices(),
		geometry->GetIndices(),
		element,
		*texture,
		Vector2f(0, 0), 
		element->GetLayout().GetPaddingSize()
	);
}

void ElementBackgroundImage::Render() {
	if (dirty) {
		dirty = false;
		Reload();
	}
	if (geometry) {
		geometry->Render(element->GetAbsoluteOffset(Layout::Area::Padding).Round());
	}
}

void ElementBackgroundImage::MarkDirty() {
	dirty = true;
}

} // namespace Rml
