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

#ifndef RMLUI_CORE_GEOMETRY_H
#define RMLUI_CORE_GEOMETRY_H

#include "Header.h"
#include "Vertex.h"
#include <stdint.h>

namespace Rml {

class Context;
class Element;
struct Texture;

class RMLUICORE_API Geometry {
public:
	Geometry();
	Geometry(const Geometry&) = delete;
	Geometry& operator=(const Geometry&) = delete;
	Geometry(Geometry&& other);
	Geometry& operator=(Geometry&& other);
	~Geometry();
	void Render();
	Vector< Vertex >& GetVertices();
	Vector< int >& GetIndices();
	void SetTexture(SharedPtr<Texture> texture);
	void Release();
	explicit operator bool() const;

	struct Path {
		void DrawArc(const Point& center, float radius_a, float radius_b, float a_min, float a_max);
		const size_t size() const { return points.size(); }
		const Point& operator[](size_t i) const { return points[i]; }
		void append(const Path& path) { points.insert(points.end(), path.points.begin(), path.points.end()); }
		void append(Point&& point) { points.emplace_back(std::forward<Point>(point)); }
		void clear() { points.clear(); }
		std::vector<Point> points;
	};

	void AddRect(const Rect& rect, Colourb col);
	void AddRect(const Rect& rect, const Rect& uv, Colourb col);
	void AddQuad(const Quad& quad, Colourb col);
	void AddArc(const Path& outer, const Path& inner, Colourb col);
	void AddPolygon(const Path& points, Colourb col);
	void UpdateUV(size_t count, const Rect& surface, const Rect& uv);
	void Reserve(size_t idx_count, size_t vtx_count);

private:
	void MoveFrom(Geometry& other);
	Vector<Vertex> vertices;
	Vector<int> indices;
	SharedPtr<Texture> texture;
};

using GeometryList = Vector< Geometry >;

} // namespace Rml
#endif
