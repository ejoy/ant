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

#include "GeometryBackgroundBorder.h"
#include "../Include/RmlUi/Layout.h"
#include "../Include/RmlUi/Math.h"
#include <algorithm>
#include <float.h>

namespace Rml {

GeometryBackgroundBorder::GeometryBackgroundBorder(Vector<Vertex>& vertices, Vector<int>& indices) : vertices(vertices), indices(indices)
{}

void GeometryBackgroundBorder::Draw(Vector<Vertex>& vertices, Vector<int>& indices, CornerInsets<float> const& border_radius, const Layout::Metrics& metrics, const Point border_position, const Colourb background_color, EdgeInsets<Colourb> const& border_colors)
{

	int num_borders = 0;

	for (int i = 0; i < 4; i++)
		if (border_colors[i].alpha > 0 && metrics.borderWidth[i] > 0)
			num_borders += 1;

	const bool has_background = (background_color.alpha > 0 && metrics.frame.size.w > 0 && metrics.frame.size.h > 0);
	const bool has_border = (num_borders > 0);

	if (!has_background && !has_border)
		return;

	// -- Find the corner positions --

	const Point padding_position = border_position + Point(metrics.borderWidth.left, metrics.borderWidth.top);
	const Size padding_size = metrics.frame.size - metrics.borderWidth;

	// Border edge positions
	CornerInsets<Point> positions_outer = {
		border_position,
		border_position + Size(metrics.frame.size.w, 0),
		border_position + metrics.frame.size,
		border_position + Size(0, metrics.frame.size.h)
	};

	// Padding edge positions
	CornerInsets<Point> positions_inner = {
		padding_position,
		padding_position + Size(padding_size.w, 0),
		padding_position + padding_size,
		padding_position + Size(0, padding_size.h)
	};

	// -- For curved borders, find the positions to draw ellipses around, and the scaled outer and inner radii --

	const float sum_radius = (border_radius.topLeft + border_radius.topRight + border_radius.bottomRight + border_radius.bottomLeft);
	const bool has_radius = (sum_radius > 1.f);

	// Curved borders are drawn as circles (outer border) and ellipses (inner border) around the centers.
	CornerInsets<Point> positions_circle_center;

	// Radii of the padding edges, 2-dimensional as these can be ellipses.
	// The inner radii is effectively the (signed) distance from the circle center to the padding edge.
	// They can also be zero or negative, in which case a sharp corner should be drawn instead of an arc.
	CornerInsets<Size> inner_radii;

	if (has_radius)
	{
		// Scale the radii such that we have no overlapping curves.
		float scale_factor = FLT_MAX;
		scale_factor = Math::Min(scale_factor, padding_size.w / (border_radius.topLeft + border_radius.topRight));       // Top
		scale_factor = Math::Min(scale_factor, padding_size.h / (border_radius.topRight + border_radius.bottomRight));   // Right
		scale_factor = Math::Min(scale_factor, padding_size.w / (border_radius.bottomRight + border_radius.bottomLeft)); // Bottom
		scale_factor = Math::Min(scale_factor, padding_size.h / (border_radius.bottomLeft + border_radius.topLeft));     // Left

		scale_factor = Math::Min(1.0f, scale_factor);

		for (int corner = 0; corner < 4; corner++) {
			border_radius[corner] = Math::RoundFloat(border_radius[corner] * scale_factor);
		}

		// Place the circle/ellipse centers
		positions_circle_center = {
			positions_outer.topLeft     + Size(border_radius.topLeft, border_radius.topLeft),
			positions_outer.topRight    + Size(-border_radius.topRight, border_radius.topRight),
			positions_outer.bottomRight + Size(-border_radius.bottomRight, -border_radius.bottomRight),
			positions_outer.bottomLeft  + Size(border_radius.bottomLeft, -border_radius.bottomLeft)
		};

		inner_radii = {
			{ border_radius.topLeft     - metrics.borderWidth.left,  border_radius.topLeft     - metrics.borderWidth.top },
			{ border_radius.topRight    - metrics.borderWidth.right, border_radius.topRight    - metrics.borderWidth.top },
			{ border_radius.bottomRight - metrics.borderWidth.right, border_radius.bottomRight - metrics.borderWidth.bottom },
			{ border_radius.topLeft     - metrics.borderWidth.left,  border_radius.topLeft     - metrics.borderWidth.bottom }
		};
	}

	// -- Generate the geometry --

	GeometryBackgroundBorder geometry(vertices, indices);

	{
		// Reserve geometry. A conservative estimate, does not take border-radii into account and assumes same-colored borders.
		const int estimated_num_vertices = 4 * int(has_background) + 2 * num_borders;
		const int estimated_num_triangles = 2 * int(has_background) + 2 * num_borders;

		vertices.reserve((int)vertices.size() + estimated_num_vertices);
		indices.reserve((int)indices.size() + 3 * estimated_num_triangles);
	}

	// Draw the background
	if (has_background)
	{
		const int offset_vertices = (int)vertices.size();

		for (int corner = 0; corner < 4; corner++)
			geometry.DrawBackgroundCorner(corner, positions_inner[corner], positions_circle_center[corner], border_radius[corner], inner_radii[corner], background_color);

		geometry.FillBackground(offset_vertices);
	}

	// Draw the border
	if (has_border)
	{
		using Edge = Layout::Edge;
		const int offset_vertices = (int)vertices.size();

		const EdgeInsets<bool> draw_edge = {
			metrics.borderWidth.left > 0 && border_colors.left.alpha > 0,
			metrics.borderWidth.top > 0 && border_colors.top.alpha > 0,
			metrics.borderWidth.right > 0 && border_colors.right.alpha > 0,
			metrics.borderWidth.bottom > 0 && border_colors.bottom.alpha > 0,
		};

		const CornerInsets<bool> draw_corner = {
			draw_edge.top || draw_edge.left,
			draw_edge.top || draw_edge.right,
			draw_edge.bottom|| draw_edge.right,
			draw_edge.bottom || draw_edge.left
		};

		for (int corner = 0; corner < 4; corner++) {
			const Edge edge0 = Edge((corner + 3) % 4);
			const Edge edge1 = Edge(corner);
			if (draw_corner[corner]) {
				geometry.DrawBorderCorner(corner, positions_outer[corner], positions_inner[corner], positions_circle_center[corner],
					border_radius[corner], inner_radii[corner], border_colors[edge0], border_colors[edge1]);
			}

			if (draw_edge[edge1]) {
				RMLUI_ASSERTMSG(draw_corner[corner] && draw_corner[(corner + 1) % 4], "Border edges can only be drawn if both of its connected corners are drawn.");
				geometry.FillEdge(edge1 == Edge::LEFT ? offset_vertices : (int)vertices.size());
			}
		}
	}
}

void GeometryBackgroundBorder::DrawBackgroundCorner(int corner, Point pos_inner, Point pos_circle_center, float R, Size r, Colourb color)
{
	if (R == 0 || r.w <= 0 || r.h <= 0)
	{
		DrawPoint(pos_inner, color);
	}
	else if (r.w > 0 && r.h > 0)
	{
		const float a0 = float((int)corner + 2) * 0.5f * Math::RMLUI_PI;
		const float a1 = float((int)corner + 3) * 0.5f * Math::RMLUI_PI;
		const int num_points = GetNumPoints(R);
		DrawArc(pos_circle_center, r, a0, a1, color, color, num_points);
	}
}

void GeometryBackgroundBorder::DrawPoint(Point pos, Colourb color)
{
	const int offset_vertices = (int)vertices.size();

	vertices.resize(offset_vertices + 1);

	vertices[offset_vertices].pos = pos;
	vertices[offset_vertices].col = color;
}

void GeometryBackgroundBorder::DrawArc(Point pos_center, Size r, float a0, float a1, Colourb color0, Colourb color1, int num_points)
{
	RMLUI_ASSERT(num_points >= 2 && r.w > 0 && r.h > 0);

	const int offset_vertices = (int)vertices.size();

	vertices.resize(offset_vertices + num_points);

	for (int i = 0; i < num_points; i++)
	{
		const float t = float(i) / float(num_points - 1);

		const float a = Math::Lerp(t, a0, a1);
		const Colourb color = Math::Lerp(t, color0, color1);

		vertices[offset_vertices + i].pos = pos_center + Size(r.w * Math::Cos(a), r.h * Math::Sin(a));
		vertices[offset_vertices + i].col = color;
	}
}

void GeometryBackgroundBorder::FillBackground(int index_start)
{
	const int num_added_vertices = (int)vertices.size() - index_start;
	const int offset_indices = (int)indices.size();

	const int num_triangles = (num_added_vertices - 2);

	indices.resize(offset_indices + 3 * num_triangles);

	for (int i = 0; i < num_triangles; i++)
	{
		indices[offset_indices + 3 * i] = index_start;
		indices[offset_indices + 3 * i + 1] = index_start + i + 2;
		indices[offset_indices + 3 * i + 2] = index_start + i + 1;
	}
}

void GeometryBackgroundBorder::DrawBorderCorner(int corner, Point pos_outer, Point pos_inner, Point pos_circle_center, float R, Size r, Colourb color0, Colourb color1)
{
	const float a0 = float((int)corner + 2) * 0.5f * Math::RMLUI_PI;
	const float a1 = float((int)corner + 3) * 0.5f * Math::RMLUI_PI;

	if (R == 0)
	{
		DrawPointPoint(pos_outer, pos_inner, color0, color1);
	}
	else if (r.w > 0 && r.h > 0)
	{
		DrawArcArc(pos_circle_center, R, r, a0, a1, color0, color1, GetNumPoints(R));
	}
	else
	{
		DrawArcPoint(pos_circle_center, pos_inner, R, a0, a1, color0, color1, GetNumPoints(R));
	}
}

void GeometryBackgroundBorder::DrawPointPoint(Point pos_outer, Point pos_inner, Colourb color0, Colourb color1)
{
	const bool different_color = (color0 != color1);

	vertices.reserve((int)vertices.size() + (different_color ? 4 : 2));

	DrawPoint(pos_inner, color0);
	DrawPoint(pos_outer, color0);

	if (different_color)
	{
		DrawPoint(pos_inner, color1);
		DrawPoint(pos_outer, color1);
	}
}

void GeometryBackgroundBorder::DrawArcArc(Point pos_center, float R, Size r, float a0, float a1, Colourb color0, Colourb color1, int num_points)
{
	RMLUI_ASSERT(num_points >= 2 && R > 0 && r.w > 0 && r.h > 0);

	const int num_triangles = 2 * (num_points - 1);

	const int offset_vertices = (int)vertices.size();
	const int offset_indices = (int)indices.size();

	vertices.resize(offset_vertices + 2 * num_points);
	indices.resize(offset_indices + 3 * num_triangles);

	for (int i = 0; i < num_points; i++)
	{
		const float t = float(i) / float(num_points - 1);

		const float a = Math::Lerp(t, a0, a1);
		const Colourb color = Math::Lerp(t, color0, color1);

		vertices[offset_vertices + 2 * i].pos = pos_center + Size(r.w * Math::Cos(a), r.h * Math::Sin(a));
		vertices[offset_vertices + 2 * i].col = color;
		vertices[offset_vertices + 2 * i + 1].pos = pos_center + Size(R * Math::Cos(a), R * Math::Sin(a));
		vertices[offset_vertices + 2 * i + 1].col = color;
	}

	for (int i = 0; i < num_triangles; i += 2)
	{
		indices[offset_indices + 3 * i + 0] = offset_vertices + i + 0;
		indices[offset_indices + 3 * i + 1] = offset_vertices + i + 2;
		indices[offset_indices + 3 * i + 2] = offset_vertices + i + 1;

		indices[offset_indices + 3 * i + 3] = offset_vertices + i + 1;
		indices[offset_indices + 3 * i + 4] = offset_vertices + i + 2;
		indices[offset_indices + 3 * i + 5] = offset_vertices + i + 3;
	}
}

void GeometryBackgroundBorder::DrawArcPoint(Point pos_center, Point pos_inner, float R, float a0, float a1, Colourb color0, Colourb color1, int num_points)
{
	RMLUI_ASSERT(R > 0 && num_points >= 2);

	const int offset_vertices = (int)vertices.size();
	vertices.reserve(offset_vertices + num_points + 2);

	// Generate the vertices. We could also split the arc mid-way to create a sharp color transition.
	DrawPoint(pos_inner, color0);
	DrawArc(pos_center, Size(R, R), a0, a1, color0, color1, num_points);
	DrawPoint(pos_inner, color1);

	RMLUI_ASSERT((int)vertices.size() - offset_vertices == num_points + 2);

	// Swap the last two vertices such that the outer edge vertex is last, see the comment for the border drawing functions. Their colors should already be the same.
	const int last_vertex = (int)vertices.size() - 1;
	std::swap(vertices[last_vertex - 1].pos, vertices[last_vertex].pos);

	// Generate the indices
	const int num_triangles = (num_points - 1);

	const int i_vertex_inner0 = offset_vertices;
	const int i_vertex_inner1 = last_vertex - 1;

	const int offset_indices = (int)indices.size();
	indices.resize(offset_indices + 3 * num_triangles);

	for (int i = 0; i < num_triangles; i++)
	{
		indices[offset_indices + 3 * i + 0] = (i > num_triangles / 2 ? i_vertex_inner1 : i_vertex_inner0);
		indices[offset_indices + 3 * i + 1] = offset_vertices + i + 2;
		indices[offset_indices + 3 * i + 2] = offset_vertices + i + 1;
	}

	// Since we swapped the last two vertices we also need to change the last triangle.
	indices[offset_indices + 3 * (num_triangles - 1) + 1] = last_vertex;
}

void GeometryBackgroundBorder::FillEdge(int index_next_corner)
{
	const int offset_indices = (int)indices.size();
	const int num_vertices = (int)vertices.size();
	RMLUI_ASSERT(num_vertices >= 2);

	indices.resize(offset_indices + 6);

	indices[offset_indices + 0] = num_vertices - 2;
	indices[offset_indices + 1] = index_next_corner;
	indices[offset_indices + 2] = num_vertices - 1;

	indices[offset_indices + 3] = num_vertices - 1;
	indices[offset_indices + 4] = index_next_corner;
	indices[offset_indices + 5] = index_next_corner + 1;
}

int GeometryBackgroundBorder::GetNumPoints(float R) const
{
	return Math::Clamp(3 + Math::RoundToInteger(R / 6.f), 2, 100);
}

} // namespace Rml
