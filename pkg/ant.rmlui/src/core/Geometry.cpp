#include <core/Geometry.h>
#include <binding/Context.h>
#include <core/Interface.h>
#include <utility>

namespace Rml {

static float PointCross(const Point& p1, const Point& p2) {
	return p1.x * p2.x + p1.y * p2.y;
}

static bool PointCrossFastCheck(const Point& p1,const Point& p2,const Point& q1,const Point& q2) {
	return true
		&& std::min(p1.x, p2.x) <= std::max(q1.x, q2.x)
		&& std::min(q1.x, q2.x) <= std::max(p1.x, p2.x)
		&& std::min(p1.y, p2.y) <= std::max(q1.y, q2.y)
		&& std::min(q1.y, q2.y) <= std::max(p1.y, p2.y)
		;
}

static bool PointCrossCheck(const Point& p1, const Point& p2, const Point& q1, const Point& q2) {
	Point Q2Q1 = q2 - q1;
	Point P1Q1 = p1 - q1;
	Point P2Q1 = p2 - q1;
	float c1 = PointCross(P1Q1, Q2Q1);
	float c2 = PointCross(P2Q1, Q2Q1);
	if ((c1 != 0 || c2 != 0) && (c1 * c2 <= 0)) {
		return false;
	}
	Point P2P1 = p2 - p1;
	Point Q1P1 = q1 - p1;
	Point Q2P1 = q2 - p1;
	float c3 = PointCross(Q1P1, P2P1);
	float c4 = PointCross(Q2P1, P2P1);
	if ((c3 != 0 || c4 != 0) && (c3 * c4 <= 0)) {
		return false;
	}
	return true;
}

static bool PointCmp(const Point& a, const Point& b, const Point& center) {
	if (a.x >= 0 && b.x < 0)
		return true;
	if (a.x == 0 && b.x == 0)
		return a.y > b.y;
	float det = (a.x - center.x) * (b.y - center.y) - (b.x - center.x) * (a.y - center.y);
	if (det < 0)
		return true;
	if (det > 0)
		return false;
	float d1 = (a.x - center.x) * (a.x - center.x) + (a.y - center.y) * (a.y - center.y);
	float d2 = (b.x - center.x) * (b.x - center.y) + (b.y - center.y) * (b.y - center.y);
	return d1 > d2;
}

static bool PointGetCross(const Point& p1, const Point& p2, const Point& q1, const Point& q2, Point& pt) {
	if (PointCrossFastCheck(p1, p2, q1, q2)) {
		if (PointCrossCheck(p1, p2, q1, q2)) {
			float xLeft = (q2.x - q1.x) * (p1.y - p2.y) - (p2.x - p1.x) * (q1.y - q2.y);
			float xRight = (p1.y - q1.y) * (p2.x - p1.x) * (q2.x - q1.x) + q1.x * (q2.y - q1.y) * (p2.x - p1.x) - p1.x * (p2.y - p1.y) * (q2.x - q1.x);
			float yLeft = (p1.x - p2.x) * (q2.y - q1.y) - (p2.y - p1.y) * (q1.x - q2.x);
			float yRight = p2.y * (p1.x - p2.x) * (q2.y - q1.y) + (q2.x- p2.x) * (q2.y - q1.y) * (p1.y - p2.y) - q2.y * (q1.x - q2.x) * (p2.y - p1.y); 
			pt.x = xRight / xLeft;
			pt.y = yRight / yLeft;
			return true;
		}
	}
	return false;
}

static bool PolygonContainPoint(const Geometry::Path& poly, const Point& pt) {
	bool c = false;
	size_t i, j;
	for (i = 0, j = poly.size() - 1; i < poly.size(); j = i++) {
		if (((poly[i].y <= pt.y) && (pt.y < poly[j].y)) || ((poly[j].y <= pt.y) && (pt.y < poly[i].y))) {
			if ((pt.x < (poly[j].x - poly[i].x) * (pt.y - poly[i].y)/(poly[j].y - poly[i].y) + poly[i].x)) {
				c = !c;
			}
		}
	}
	return c;
}

static void PolygonSort(Geometry::Path& poly) {
	Point center;
	float x = 0.f;
	float y = 0.f;
	for (size_t i = 0; i < poly.size(); ++i) {
		x += poly[i].x;
		y += poly[i].y;
	}
	center.x = x / poly.size();
	center.y = y / poly.size();

	std::sort(poly.points.begin(), poly.points.end(), [&](const Point& a, const Point& b){
		return PointCmp(a, b, center);
	});
}

static Geometry::Path PolygonClip(const Geometry::Path& poly1, const Geometry::Path& poly2) {
	if (poly1.size() < 3 || poly2.size() < 3) {
		return {};
	}
	Geometry::Path clip;
	for (size_t i = 0; i < poly1.size(); ++i) {
		size_t poly1_next_idx = (i + 1) % poly1.size();
		for (size_t j = 0; j < poly2.size(); ++j) {
			size_t poly2_next_idx = (j + 1) % poly2.size();
			Point pt;
			if (PointGetCross(poly1[i], poly1[poly1_next_idx], poly2[j], poly2[poly2_next_idx], pt)) {
				clip.push(pt);
			}
		}
	}
	for (const Point& pt : poly1.points) {
		if (PolygonContainPoint(poly2, pt)) {
			clip.push(pt);
		}
	}
	for (const Point& pt : poly2.points) {
		if (PolygonContainPoint(poly1, pt)) {
			clip.push(pt);
		}
	}
	if (clip.size() <= 0) {
		return {};
	}
	PolygonSort(clip);
	return clip;
}

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

Geometry::Path Geometry::ClipPolygon(const Path& poly1, const Rect& rect) {
	Path poly2;
	auto points = rect.Vertex();
	poly2.push(points.topLeft);
	poly2.push(points.topRight);
	poly2.push(points.bottomRight);
	poly2.push(points.bottomLeft);
	return PolygonClip(poly1, poly2);
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
