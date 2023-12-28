#include <core/Geometry.h>
#include <binding/Context.h>
#include <core/Interface.h>
#include <utility>

namespace Rml {


void Geometry::Render() {
	if (vertices.empty() || indices.empty())
		return;
	GetRender()->RenderGeometry(
		&vertices[0],
		vertices.size(),
		&indices[0],
		indices.size(),
		material
	);
}

std::vector<Vertex>& Geometry::GetVertices() {
	return vertices;
}

std::vector<Index>& Geometry::GetIndices() {
	return indices;
}

Geometry::Geometry()
	: vertices()
	, indices()
	, material(GetRender()->CreateDefaultMaterial())
{}

Geometry::~Geometry() {
	Release();
}

void Geometry::Release() {
	vertices.clear();
	indices.clear();
	SetMaterial(GetRender()->CreateDefaultMaterial());
}

void Geometry::SetMaterial(Material* mat) {
	GetRender()->DestroyMaterial(material);
	material = mat;
}

Geometry::operator bool() const {
	return !indices.empty();
}

static void DrawQuadIdx(Index* idx, Index idx_offset) {
	idx[0] = idx_offset + 0; idx[1] = idx_offset + 1; idx[2] = idx_offset + 2;
	idx[3] = idx_offset + 0; idx[4] = idx_offset + 2; idx[5] = idx_offset + 3;
}

static void DrawQuadPos(Vertex* vtx, const Point& a, const Point& b, const Point& c, const Point& d) {
	vtx[0].pos = a;
	vtx[1].pos = b;
	vtx[2].pos = c;
	vtx[3].pos = d;
}

static void DrawQuadColor(Vertex* vtx, const Color& col) {
	vtx[0].col = col;
	vtx[1].col = col;
	vtx[2].col = col;
	vtx[3].col = col;
}

static void DrawQuadUV(Vertex* vtx, const Point& a, const Point& b, const Point& c, const Point& d) {
	vtx[0].uv = a;
	vtx[1].uv = b;
	vtx[2].uv = c;
	vtx[3].uv = d;
}

static void DrawQuad(Vertex* vtx, Index* idx, Index idx_offset, const Point& a, const Point& b, const Point& c, const Point& d, const Color& col) {
	DrawQuadIdx(idx, idx_offset);
	DrawQuadPos(vtx, a, b, c, d);
	DrawQuadColor(vtx, col);
}

static void DrawRect(Vertex* vtx, Index* idx, Index idx_offset, const Rect& pos, const Color& col) {
	Point topLeft = pos.origin;
	Point bottomRight = pos.origin + pos.size;
	DrawQuad(vtx, idx, idx_offset, topLeft, Point(bottomRight.x, topLeft.y), bottomRight, Point(topLeft.x, bottomRight.y), col);
}

static void DrawRectUV(Vertex* vtx, const Rect& uv) {
	Point topLeft = uv.origin;
	Point bottomRight = uv.origin + uv.size;
	DrawQuadUV(vtx, topLeft, Point(bottomRight.x, topLeft.y), bottomRight, Point(topLeft.x, bottomRight.y));
}

static Point PointClamp(const Point& v, const Point& mn, const Point& mx) {
	return Point(
		(v.x < mn.x) ? mn.x : (v.x > mx.x) ? mx.x : v.x,
		(v.y < mn.y) ? mn.y : (v.y > mx.y) ? mx.y : v.y
	);
}

void Geometry::AddRectFilled(const Rect& rect, Color col) {
	if (!col.IsVisible()) {
		return;
	}
	if (rect.size.w == 0 || rect.size.h == 0) {
		return;
	}
	size_t vsz = vertices.size();
	size_t isz = indices.size();
	Reserve(6, 4);
	Vertex* vtx = &vertices[vsz];
	Index* idx = &indices[isz];
	DrawRect(vtx, idx, (Index)vsz, rect, col);
}

void Geometry::AddQuad(const Quad& quad, Color col) {
	if (!col.IsVisible()) {
		return;
	}
	if (quad.a == quad.b && quad.c == quad.d) {
		return;
	}
	if (quad.a == quad.d && quad.b == quad.c) {
		return;
	}
	size_t vsz = vertices.size();
	size_t isz = indices.size();
	Reserve(6, 4);
	Vertex* vtx = &vertices[vsz];
	Index* idx = &indices[isz];
	DrawQuad(vtx, idx, (Index)vsz, quad.a, quad.b, quad.c, quad.d, col);
}

void Geometry::AddRectFilled(const Rect& rect, const Rect& uv, Color col) {
	if (!col.IsVisible()) {
		return;
	}
	if (rect.size.w == 0 || rect.size.h == 0) {
		return;
	}
	size_t vsz = vertices.size();
	size_t isz = indices.size();
	Reserve(6, 4);
	Vertex* vtx = &vertices[vsz];
	Index* idx = &indices[isz];
	DrawRect(vtx, idx, (Index)vsz, rect, col);
	DrawRectUV(vtx, uv);
}

void Geometry::AddRect(const Rect& inner, float width, Color col) {
	Rect outer = inner + EdgeInsets<float> {width,width,width,width};
	CornerInsets<Point> outerVertex = outer.Vertex();
	CornerInsets<Point> innerVertex = inner.Vertex();
	AddQuad(Quad {
		outerVertex.topLeft,
		outerVertex.topRight,
		innerVertex.topRight,
		innerVertex.topLeft,
	}, col);
	AddQuad(Quad {
		outerVertex.topRight,
		outerVertex.bottomRight,
		innerVertex.bottomRight,
		innerVertex.topRight,
	}, col);
	AddQuad(Quad {
		outerVertex.bottomRight,
		outerVertex.bottomLeft,
		innerVertex.bottomLeft,
		innerVertex.bottomRight,
	}, col);
	AddQuad(Quad {
		outerVertex.bottomLeft,
		outerVertex.topLeft,
		innerVertex.topLeft,
		innerVertex.bottomLeft,
	}, col);
}

void Geometry::AddArc(const Path& outer, const Path& inner, Color col) {
	if (col.a == 0) {
		return;
	}
	size_t outer_count = outer.size();
	size_t inner_count = inner.size();
	size_t count = outer_count + inner_count;
	assert(outer_count >= inner_count);
	if (count <= 2) {
		return;
	}
	size_t vsz = vertices.size();
	size_t isz = indices.size();
	Reserve((count - 2) * 3, count);
	Vertex* vtx = &vertices[vsz];
	Index* idx = &indices[isz];

	for (size_t i = 0; i < outer_count; ++i) {
		vtx[i].pos = outer[i];
	}
	for (size_t i = 0; i < inner_count; ++i) {
		vtx[outer_count + i].pos = inner[i];
	}
	for (size_t i = 0; i < count; ++i) {
		vtx[i].col = col;
	}

	Index outer_offset = (Index)vsz;
	Index inner_offset = (Index)(vsz + outer_count);
	Index diff = (Index)outer_count - (Index)inner_count;
	Index prefix = diff / 2;
	Index suffix = diff - diff / 2;
	for (Index i = 0; i < prefix; ++i) {
		idx[0] = outer_offset + i + 0;
		idx[1] = outer_offset + i + 1;
		idx[2] = inner_offset + 0;
		idx += 3;
	}
	for (Index i = 0; i < suffix; ++i) {
		idx[0] = outer_offset + ((Index)outer_count - i - 2) + 0;
		idx[1] = outer_offset + ((Index)outer_count - i - 2) + 1;
		idx[2] = inner_offset + ((Index)inner_count - 1);
		idx += 3;
	}
	for (Index i = 0; i < (Index)inner_count - 1; ++i) {
		idx[0] = outer_offset + prefix + i + 0;
		idx[1] = outer_offset + prefix + i + 1;
		idx[2] = inner_offset + i + 1;
		idx[3] = outer_offset + prefix + i + 0;
		idx[4] = inner_offset + i + 1;
		idx[5] = inner_offset + i + 0;
		idx += 6;
	}
}

void Geometry::AddPolygon(const Path& points, Color col) {
	if (col.a == 0) {
		return;
	}
	size_t vsz = vertices.size();
	size_t isz = indices.size();
	size_t points_count = points.size();
	assert(points_count > 2);
	Reserve((points_count - 2) * 3, points_count);
	Vertex* vtx = &vertices[vsz];
	Index* idx = &indices[isz];

	for (size_t i = 0; i < points_count; ++i) {
		vtx[i].pos = points[i];
		vtx[i].col = col;
	}

	Index offset = (Index)vsz;
	for (size_t i = 0; i < points_count - 2; ++i) {
		idx[0] = offset + 0;
		idx[1] = offset + (Rml::Index)i + 1;
		idx[2] = offset + (Rml::Index)i + 2;
		idx += 3;
	}
}

void Geometry::UpdateVertices()
{
/* 	for(size_t i = 0; i < vertices.size(); ++i)
	{
 		float posx = floorf(vertices[i].pos.x - float(0.5));
		float posy = floorf(vertices[i].pos.y - float(0.5));
		vertices[i].pos = Point(posx, posy); 
	} */
}

void Geometry::UpdateUV(size_t count, const Rect& surface, const Rect& uv) {
	Vertex* vtx = &vertices[vertices.size() - count];
	const Size size = surface.size;
	const Size uv_size = uv.size;
	const Point scale { uv_size.w / size.w, uv_size.h / size.h };
	const Point a = surface.origin;
	const Point uv_a = uv.origin;
	const Point min = uv.origin;
	const Point max = uv.origin + uv.size;
	for (size_t i = 0; i < count; ++i) {
		vtx[i].uv = PointClamp(uv_a + (vtx[i].pos - a) * scale, min, max);
	}
}

void Geometry::Reserve(size_t idx_count, size_t vtx_count) {
	size_t isz = indices.size();
	size_t vsz = vertices.size();
	indices.resize(isz + idx_count);
	vertices.resize(vsz + vtx_count);
}

void Geometry::Path::DrawArc(const Point& center, float radius_a, float radius_b, float a_min, float a_max) {
	if (radius_a == 0.0f || radius_b == 0.0f) {
		points.push_back(center);
		return;
	}
	int num_segments = std::min(3 + int((radius_a + radius_b) / 12.f), 100);
	points.reserve(points.size() + num_segments + 1);
	for (int i = 0; i <= num_segments; i++) {
		const float a = a_min + ((float)i / (float)num_segments) * (a_max - a_min);
		points.push_back(center + Point(cosf(a) * radius_a, sinf(a) * radius_b));
	}
}

void Geometry::SetGray() {
	assert(material);
	if (!material->SetGray()) {
		for (auto& vtx : vertices) {
			vtx.col.SetGray();
		}
	}
}

}
