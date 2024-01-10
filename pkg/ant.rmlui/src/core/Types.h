#pragma once

#include <algorithm>
#include <cstdint>
#include <tuple>
#include <glm/gtc/matrix_transform.hpp>

namespace Rml {

typedef uint8_t PseudoClassSet;

enum class PseudoClass : uint8_t {
	Hover  = 0x01,
	Active = 0x02,
};

inline PseudoClassSet operator| (PseudoClass a, PseudoClass b) { return (uint8_t)a | (uint8_t)b; }
inline PseudoClassSet operator| (PseudoClassSet a, PseudoClass b) { return a | (uint8_t)b; }
inline PseudoClassSet operator~ (PseudoClass a) { return ~(uint8_t)a; }
inline PseudoClassSet operator& (PseudoClassSet a, PseudoClass b) { return a & (uint8_t)b; }

struct Point {
	float x{};
	float y{};
	Point() {}
	Point(float x_, float y_) : x(x_), y(y_) {}
	void SetPoint(float x_, float y_) {
		x = x_;
		y = y_;
	}
};

struct Size {
	float w{};
	float h{};
	Size() {}
	Size(float width, float height) : w(width), h(height) {}
	bool IsEmpty() const { return !w || !h; }
	void SetSize(float width, float height) {
		w = width;
		h = height;
	}
};

struct Quad {
	Point a, b, c, d;
};

template <typename T>
struct EdgeInsets {
	T left{};
	T top{};
	T right{};
	T bottom{};
	T& operator[](size_t i) const {
		return ((T*)this)[i];
	}
	bool operator==(const EdgeInsets& rhs) const {
		return std::tie(left, top, right, bottom) == std::tie(rhs.left, rhs.top, rhs.right, bottom);
	}
	bool operator!=(const EdgeInsets& rhs) const {
		return !(*this == rhs);
	}
};

template <typename T>
struct CornerInsets {
	T topLeft{};
	T topRight{};
	T bottomRight{};
	T bottomLeft{};
	T& operator[](size_t i) const {
		return ((T*)this)[i];
	}
	bool operator==(const CornerInsets& rhs) const {
		return std::tie(topLeft, topRight, bottomLeft, bottomRight) == std::tie(rhs.topLeft, rhs.topRight, rhs.bottomLeft, bottomRight);
	}
	bool operator!=(const CornerInsets& rhs) const {
		return !(*this == rhs);
	}
};

struct Rect {
	Point origin;
	Size size;
	Rect() : origin(), size() {}
	Rect(float x, float y, float width, float height) : origin(x, y), size(width, height) {}
	Rect(const Point& origin_, const Size& size_) : origin(origin_), size(size_) {}
	float x() const { return origin.x; }
	float y() const { return origin.y; }
	float width() const { return size.w; }
	float height() const { return size.h; }
	float left() const { return origin.x; }
	float top() const { return origin.y; }
	float right() const { return left() + width(); }
	float bottom() const { return top() + height(); }
	bool IsEmpty() const { return size.IsEmpty(); }
	void SetRect(float x, float y, float width, float height) {
		origin.SetPoint(x, y);
		size.SetSize(width, height);
	}
	void Union(const Rect& rect) {
		float l = std::min(left(), rect.left());
		float t = std::min(top(), rect.top());
		float r = std::max(right(), rect.right());
		float b = std::max(bottom(), rect.bottom());
		SetRect(l, t, r - l, b - t);
	}
	bool HasInter(const Rect& rect) const {
		if (left() > rect.right() || rect.left() > right() || top() > rect.bottom() || rect.top() > bottom()) {
			return false;
		}
		return true;
	}
	void Inter(const Rect& rect) {
		if (!HasInter(rect)) {
			SetRect(0, 0, 0, 0);
			return;
		}
		float l = std::max(left(), rect.left());
		float t = std::max(top(), rect.top());
		float r = std::min(right(), rect.right());
		float b = std::min(bottom(), rect.bottom());
		SetRect(l, t, r - l, b - t);
	}
	bool Contains(const Point& point) const {
		return (point.x >= x()) && (point.x < right()) && (point.y >= y()) && (point.y < bottom());
	}
	CornerInsets<Point> Vertex() const {
		return {
			{left(), top()},
			{right(), top()},
			{right(), bottom()},
			{left(), bottom()}
		};
	}
};

inline bool operator==(const Point& lhs, const Point& rhs) {
	return lhs.x == rhs.x && lhs.y == rhs.y;
}
inline bool operator!=(const Point& lhs, const Point& rhs) {
	return !(lhs == rhs);
}
inline bool operator==(const Size& lhs, const Size& rhs) {
	return lhs.w == rhs.w && lhs.h == rhs.h;
}
inline bool operator!=(const Size& lhs, const Size& rhs) {
	return !(lhs == rhs);
}
inline bool operator==(const Rect& lhs, const Rect& rhs) {
	return lhs.origin == rhs.origin && lhs.size == rhs.size;
}
inline bool operator!=(const Rect& lhs, const Rect& rhs) {
	return !(lhs == rhs);
}

inline Point operator+(const Point& lhs, const Point& rhs) {
	return Point(lhs.x + rhs.x, lhs.y + rhs.y);
}
inline Point operator-(const Point& lhs, const Point& rhs) {
	return Point(lhs.x - rhs.x, lhs.y - rhs.y);
}
inline Point operator+(const Point& lhs, const Size& rhs) {
	return Point(lhs.x + rhs.w, lhs.y + rhs.h);
}
inline Point operator-(const Point& lhs, const Size& rhs) {
	return Point(lhs.x - rhs.w, lhs.y - rhs.h);
}
inline Size operator+(const Size& lhs, const Size& rhs) {
	return Size(lhs.w + rhs.w, lhs.h + rhs.h);
}
inline Size operator-(const Size& lhs, const Size& rhs) {
	return Size(lhs.w - rhs.w, lhs.h - rhs.h);
}

inline EdgeInsets<float> operator+(const EdgeInsets<float>& lhs, const EdgeInsets<float>& rhs) {
	return EdgeInsets<float> {
		lhs.left + rhs.left,
		lhs.top + rhs.top,
		lhs.right + rhs.right,
		lhs.bottom + rhs.bottom,
	};
}

inline Point operator+(const Point& lhs, const EdgeInsets<float>& rhs) {
	return Point(lhs.x + rhs.left, lhs.y + rhs.top);
}
inline Point operator-(const Point& lhs, const EdgeInsets<float>& rhs) {
	return Point(lhs.x - rhs.left, lhs.y - rhs.top);
}
inline Size operator+(const Size& lhs, const EdgeInsets<float>& rhs) {
	return Size(lhs.w + rhs.left + rhs.right, lhs.h + rhs.top + rhs.bottom);
}
inline Size operator-(const Size& lhs, const EdgeInsets<float>& rhs) {
	return Size(lhs.w - rhs.left - rhs.right, lhs.h - rhs.top - rhs.bottom);
}
inline Rect operator+(const Rect& lhs, const EdgeInsets<float>& rhs) {
	return Rect(lhs.origin - rhs, lhs.size + rhs);
}
inline Rect operator-(const Rect& lhs, const EdgeInsets<float>& rhs) {
	return Rect(lhs.origin + rhs, lhs.size - rhs);
}

inline Point operator*(const Point& lhs, const Point& rhs) {
	return Point(lhs.x * rhs.x, lhs.y * rhs.y);
}
inline Size operator*(const Size& lhs, float rhs) {
	return Size(lhs.w * rhs, lhs.h * rhs);
}
inline Point operator/(const Point& lhs, Size rhs) {
	return Point(lhs.x / rhs.w, lhs.y / rhs.h);
}
inline Size operator/(const Size& lhs, Size rhs) {
	return Size(lhs.w / rhs.w, lhs.h / rhs.h);
}
}
