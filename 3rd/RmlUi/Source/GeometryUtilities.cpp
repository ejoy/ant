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

#include "../Include/RmlUi/GeometryUtilities.h"
#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/FontEngineInterface.h"
#include "../Include/RmlUi/Geometry.h"
#include "../Include/RmlUi/Types.h"
#include "GeometryBackgroundBorder.h"

namespace Rml {

static void DrawQuad(Vertex* vertices, int* indices, Rect rect, Colourb colour, Rect texcoord, int index_offset)
{
	vertices[0].pos = rect.origin;
	vertices[0].col = colour;
	vertices[0].uv = Point(texcoord.left(), texcoord.top());

	vertices[1].pos = rect.origin + Size(rect.size.w, 0);
	vertices[1].col = colour;
	vertices[1].uv = Point(texcoord.right(), texcoord.top());

	vertices[2].pos = rect.origin + rect.size;
	vertices[2].col = colour;
	vertices[2].uv = Point(texcoord.right(), texcoord.bottom());

	vertices[3].pos = rect.origin + Size(0, rect.size.h);
	vertices[3].col = colour;
	vertices[3].uv = Point(texcoord.left(), texcoord.bottom());

	indices[0] = index_offset + 0;
	indices[1] = index_offset + 3;
	indices[2] = index_offset + 1;

	indices[3] = index_offset + 1;
	indices[4] = index_offset + 3;
	indices[5] = index_offset + 2;
}

void GeometryUtilities::GenerateRect(Geometry& geometry, Rect rect, Colourb colour, Rect texcoord){
	Vector<Vertex>& vertices = geometry.GetVertices();
	Vector<int>& indices = geometry.GetIndices();
	size_t vsz = vertices.size();
	size_t isz = indices.size();
	vertices.resize(vsz + 4);
	indices.resize(isz + 6);
	DrawQuad(
		&vertices[vsz], &indices[isz],
		rect,
		colour,
		texcoord,
		(int)vsz
	);
}

void GeometryUtilities::GenerateBackgroundBorder(Geometry& geometry, const Layout::Metrics& metrics, Point border_position, CornerInsets<float> const& border_radius, Colourb background_colour, EdgeInsets<Colourb> const& border_colours)
{
	Vector<Vertex>& vertices = geometry.GetVertices();
	Vector<int>& indices = geometry.GetIndices();
	GeometryBackgroundBorder::Draw(vertices, indices, border_radius, metrics, border_position, background_colour, border_colours);
}

} // namespace Rml
