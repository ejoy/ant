#pragma once

#include <core/Types.h>
#include <core/Color.h>
#include <memory>
#include <vector>
#include <stdint.h>

namespace Rml {

using MaterialHandle = uintptr_t;

enum class SamplerFlag : uint8_t {
	Repeat,
	RepeatX,
	RepeatY,
	NoRepeat,
	Unset,
};

struct Vertex {
	Point pos;
	Color col;
	Point uv;
};

using Index = uint32_t;

struct Texture;

class Geometry {
public:
	Geometry() = default;
	~Geometry();
	Geometry(const Geometry&) = delete;
	Geometry& operator=(const Geometry&) = delete;
	std::vector<Vertex>& GetVertices();
	std::vector<Index>& GetIndices();
	void SetMaterial(MaterialHandle material);
	void Render();
	void Release();
	explicit operator bool() const;

	struct Path {
		void DrawArc(const Point& center, float radius_a, float radius_b, float a_min, float a_max);
		bool empty() const { return points.empty(); }
		const size_t size() const { return points.size(); }
		const Point& operator[](size_t i) const { return points[i]; }
		void append(const Path& path) { points.insert(points.end(), path.points.begin(), path.points.end()); }
		void push(Point point) { points.push_back(point); }
		void emplace(Point&& point) { points.emplace_back(std::forward<Point>(point)); }
		void clear() { points.clear(); }
		std::vector<Point> points;
	};

	void AddRectFilled(const Rect& rect, Color col);
	void AddRectFilled(const Rect& rect, const Rect& uv, Color col);
	void AddRect(const Rect& inner, float width, Color col);
	void AddQuad(const Quad& quad, Color col);
	void AddArc(const Path& outer, const Path& inner, Color col);
	void AddPolygon(const Path& points, Color col);
	void UpdateUV(size_t count, const Rect& surface, const Rect& uv);
	void Reserve(size_t idx_count, size_t vtx_count);

protected:
	std::vector<Vertex> vertices;
	std::vector<Index> indices;
	MaterialHandle material = 0;
};

}
