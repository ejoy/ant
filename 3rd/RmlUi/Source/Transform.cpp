#include "../Include/RmlUi/Transform.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/Math.h"
#include "ElementStyle.h"
#include <glm/gtx/transform.hpp>
#include <glm/gtx/string_cast.hpp>
#include <glm/gtx/compatibility.hpp>
#include <glm/gtx/matrix_decompose.hpp>

namespace Rml {

using namespace Transforms;

static float ResolveLength(NumericValue value, Element& e) noexcept {
	if (!(value.unit & (Property::NUMBER | Property::LENGTH)))
		return 0.0f;
	Property prop;
	prop.value = Variant(value.number);
	prop.unit = value.unit;
	return ComputeProperty<float>(&prop, &e);
}

static float ResolveWidth(NumericValue value, Element& e) noexcept {
	if (value.unit & Property::PERCENT) {
		return value.number * e.GetMetrics().frame.size.w * 0.01f;
	}
	return ResolveLength(value, e);
}

static float ResolveHeight(NumericValue value, Element& e) noexcept {
	if (value.unit & Property::PERCENT) {
		return value.number * e.GetMetrics().frame.size.h * 0.01f;
	}
	return ResolveLength(value, e);
}

static float ResolveDepth(NumericValue value, Element& e) noexcept {
	if (value.unit & Property::PERCENT) {
		return 0.f;
	}
	return ResolveLength(value, e);
}

static float ResolveAngle(NumericValue value) noexcept {
	switch (value.unit) {
	case Property::RAD:
		return value.number;
	case Property::DEG:
		return Math::DegreesToRadians(value.number);
	default:
		return 0.f;
	}
}

static glm::mat4x4 skew(float angle_x, float angle_y) {
	float skewX = tanf(angle_x);
	float skewY = tanf(angle_y);
	return glm::mat4x4{
		{ 1, skewX, 0, 0 },
		{ skewY, 1, 0, 0 },
		{ 0, 0, 1, 0 },
		{ 0, 0, 0, 1 }
	};
}

static glm::mat4x4 compose(const glm::vec3& translation, const glm::vec3& scale, const glm::vec3& skew, const glm::vec4& perspective, const glm::quat& quaternion) {
	glm::mat4x4 matrix(1);
	for (int i = 0; i < 4; i++)
		matrix[i][3] = perspective[i];
	for (int i = 0; i < 4; i++)
		for (int j = 0; j < 3; j++)
			matrix[3][i] += translation[j] * matrix[j][i];

	matrix *= glm::mat4x4(quaternion);

	glm::mat4x4 temp(1);
	if (skew[2]) {
		temp[2][1] = skew[2];
		matrix *= temp;
	}
	if (skew[1]) {
		temp[2][1] = 0;
		temp[2][0] = skew[1];
		matrix *= temp;
	}
	if (skew[0]) {
		temp[2][0] = 0;
		temp[1][0] = skew[0];
		matrix *= temp;
	}
	for (int i = 0; i < 3; i++)
		for (int j = 0; j < 4; j++)
			matrix[i][j] *= scale[i];
	return matrix;
}

static glm::mat4x4 matrix2d(const glm::mat3x2& m) {
	return {
		{ m[0][0], m[1][0], 0, m[2][0] },
		{ m[0][1], m[1][1], 0, m[2][1] },
		{ 0, 0, 1, 0},
		{ 0, 0, 0, 1}
	};
}

static glm::mat4x4 perspective(float distance) {
	return {
		{ 1, 0, 0, 0 },
		{ 0, 1, 0, 0 },
		{ 0, 0, 1, -1.f / distance },
		{ 0, 0, 0, 1 }
	};
}

static std::optional<DecomposedMatrix4> decompose(const glm::mat4x4& m) {
	DecomposedMatrix4 d;
	if (!glm::decompose(m, d.scale, d.quaternion, d.translation, d.skew, d.perspective)) {
		return {};
	}
	return d;
}

struct SetIdentityVisitor {
	template <typename T>
	void operator()(T& p) { p = {}; }
};

struct MultiplyVisitor {
	Element& e;
	glm::mat4x4 matrix{ 1 };

	void operator()(const Transforms::Matrix2D& p) {
		matrix *= matrix2d((glm::mat3x2&)p);
	}
	void operator()(const Transforms::Matrix3D& p) {
		matrix *= (const glm::mat4x4&)p;
	}
	void operator()(const Transforms::TranslateX& p) {
		glm::vec3 v{ 0 };
		v.x = ResolveWidth(p.x, e);
		matrix = glm::translate(matrix, v);
	}
	void operator()(const Transforms::TranslateY& p) {
		glm::vec3 v{ 0 };
		v.y = ResolveHeight(p.y, e);
		matrix = glm::translate(matrix, v);
	}
	void operator()(const Transforms::TranslateZ& p) {
		glm::vec3 v{ 0 };
		v.z = ResolveDepth(p.z, e);
		matrix = glm::translate(matrix, v);
	}
	void operator()(const Transforms::Translate2D& p) {
		glm::vec3 v{ 0 };
		v.x = ResolveWidth(p.x, e);
		v.y = ResolveHeight(p.y, e);
		matrix = glm::translate(matrix, v);
	}
	void operator()(const Transforms::Translate3D& p) {
		glm::vec3 v{ 0 };
		v.x = ResolveWidth(p.x, e);
		v.y = ResolveHeight(p.y, e);
		v.z = ResolveDepth(p.z, e);
		matrix = glm::translate(matrix, v);
	}
	void operator()(const Transforms::ScaleX& p) {
		matrix = glm::scale(matrix, { p.x, 1, 1 });
	}
	void operator()(const Transforms::ScaleY& p) {
		matrix = glm::scale(matrix, { 1, p.y, 1 });
	}
	void operator()(const Transforms::ScaleZ& p) {
		matrix = glm::scale(matrix, { 1, 1, p.z });
	}
	void operator()(const Transforms::Scale2D& p) {
		matrix = glm::scale(matrix, { p.x, p.y, 1 });
	}
	void operator()(const Transforms::Scale3D& p) {
		matrix = glm::scale(matrix, { p.x, p.y, p.z });
	}
	void operator()(const Transforms::RotateX& p) {
		float angle = ResolveAngle(p.angle);
		matrix = glm::rotate(matrix, angle, { 1, 0, 0 });
	}
	void operator()(const Transforms::RotateY& p) {
		float angle = ResolveAngle(p.angle);
		matrix = glm::rotate(matrix, angle, { 0, 1, 0 });
	}
	void operator()(const Transforms::RotateZ& p) {
		float angle = ResolveAngle(p.angle);
		matrix = glm::rotate(matrix, angle, { 0, 0, 1 });
	}
	void operator()(const Transforms::Rotate2D& p) {
		float angle = ResolveAngle(p.angle);
		matrix = glm::rotate(matrix, angle, { 0, 0, 1 });
	}
	void operator()(const Transforms::Rotate3D& p) {
		float angle = ResolveAngle(p.angle);
		matrix = glm::rotate(matrix, angle, p.axis);
	}
	void operator()(const Transforms::SkewX& p) {
		matrix *= skew(ResolveAngle(p.x), 0);
	}
	void operator()(const Transforms::SkewY& p) {
		matrix *= skew(0, ResolveAngle(p.y));
	}
	void operator()(const Transforms::Skew2D& p) {
		matrix *= skew(ResolveAngle(p.x), ResolveAngle(p.y));
	}
	void operator()(const Transforms::DecomposedMatrix4& p) {
		matrix *= compose(p.translation, p.scale, p.skew, p.perspective, p.quaternion);
	}
	void operator()(const Transforms::Perspective& p) {
		float distance = ResolveDepth(p.distance, e);
		matrix *= perspective(distance);
	}
};

struct PrepareVisitor {
	Element& e;
	TransformPrimitive& t;
	bool ok = true;
	void operator()(ScaleX&) { }
	void operator()(ScaleY&) { }
	void operator()(ScaleZ&) { }
	void operator()(Scale2D&) { }
	void operator()(Scale3D&) { }
	void operator()(DecomposedMatrix4&) { }
	void operator()(TranslateX& p) {
		p.x = NumericValue{ ResolveWidth(p.x, e), Property::PX };
	}
	void operator()(TranslateY& p) {
		p.y = NumericValue{ ResolveHeight(p.y, e), Property::PX };
	}
	void operator()(TranslateZ& p) {
		p.z = NumericValue{ ResolveDepth(p.z, e), Property::PX };
	}
	void operator()(Translate2D& p) {
		p.x = NumericValue{ ResolveWidth(p.x, e), Property::PX };
		p.y = NumericValue{ ResolveHeight(p.y, e), Property::PX };
	}
	void operator()(Translate3D& p) {
		p.x = NumericValue{ ResolveWidth(p.x, e), Property::PX };
		p.y = NumericValue{ ResolveHeight(p.y, e), Property::PX };
		p.z = NumericValue{ ResolveDepth(p.z, e), Property::PX };
	}
	void operator()(RotateX& p) {
		p.angle = NumericValue{ ResolveAngle(p.angle), Property::RAD };
	}
	void operator()(RotateY& p) {
		p.angle = NumericValue{ ResolveAngle(p.angle), Property::RAD };
	}
	void operator()(RotateZ& p) {
		p.angle = NumericValue{ ResolveAngle(p.angle), Property::RAD };
	}
	void operator()(Rotate2D& p) {
		p.angle = NumericValue{ ResolveAngle(p.angle), Property::RAD };
	}
	void operator()(Rotate3D& p) {
		p.angle = NumericValue{ ResolveAngle(p.angle), Property::RAD };
	}
	void operator()(SkewX& p) {
		p.x = NumericValue{ ResolveAngle(p.x), Property::RAD };
	}
	void operator()(SkewY& p) {
		p.y = NumericValue{ ResolveAngle(p.y), Property::RAD };
	}
	void operator()(Skew2D& p) {
		p.x = NumericValue{ ResolveAngle(p.x), Property::RAD };
		p.y = NumericValue{ ResolveAngle(p.y), Property::RAD };
	}
	void operator()(Matrix3D& p) {
		auto d = decompose((const glm::mat4x4&)p);
		if (d) { t = d.value(); }
		else { ok = false; };
	}
	void operator()(Matrix2D& p) {
		auto d = decompose(matrix2d((const glm::mat3x2&)p));
		if (d) { t = d.value(); }
		else { ok = false; };
	}
	void operator()(Perspective& p) {
		float distance = ResolveDepth(p.distance, e);
		auto d = decompose(perspective(distance));
		if (d) { t = d.value(); }
		else { ok = false; };
	}
};

struct InterpolateVisitor {
	const TransformPrimitive& other_variant;
	float alpha;
	template <typename T>
	bool operator()(T& p0) {
		interpolate(p0, std::get<T>(other_variant));
		return true;
	}
	bool operator()(Matrix3D&) { return false; }
	bool operator()(Matrix2D&) { return false; }
	bool operator()(Perspective&) { return false; }

	void interpolate(float& p0, const float& p1) {
		p0 = glm::lerp(p0, p1, alpha);
	}
	void interpolate(NumericValue& p0, const NumericValue& p1) {
		assert(p0.unit == p1.unit);
		interpolate(p0.number, p1.number);
	}
	void interpolate(DecomposedMatrix4& p0, const DecomposedMatrix4& p1) {
		p0.perspective = glm::lerp(p0.perspective, p1.perspective, alpha);
		p0.quaternion = glm::slerp(p0.quaternion, p1.quaternion, alpha);
		p0.translation = glm::lerp(p0.translation, p1.translation, alpha);
		p0.scale = glm::lerp(p0.scale, p1.scale, alpha);
		p0.skew = glm::lerp(p0.skew, p1.skew, alpha);
	}
	void interpolate(TranslateX& p0, const TranslateX& p1) { interpolate(p0.x, p1.x); }
	void interpolate(TranslateY& p0, const TranslateY& p1) { interpolate(p0.y, p1.y); }
	void interpolate(TranslateZ& p0, const TranslateZ& p1) { interpolate(p0.z, p1.z); }
	void interpolate(Translate2D& p0, const Translate2D& p1) {
		interpolate(p0.x, p1.x);
		interpolate(p0.y, p1.y);
	}
	void interpolate(Translate3D& p0, const Translate3D& p1) {
		interpolate(p0.x, p1.x);
		interpolate(p0.y, p1.y);
		interpolate(p0.z, p1.z);
	}
	void interpolate(ScaleX& p0, const ScaleX& p1) { interpolate(p0.x, p1.x); }
	void interpolate(ScaleY& p0, const ScaleY& p1) { interpolate(p0.y, p1.y); }
	void interpolate(ScaleZ& p0, const ScaleZ& p1) { interpolate(p0.z, p1.z); }
	void interpolate(Scale2D& p0, const Scale2D& p1) {
		interpolate(p0.x, p1.x);
		interpolate(p0.y, p1.y);
	}
	void interpolate(Scale3D& p0, const Scale3D& p1) {
		interpolate(p0.x, p1.x);
		interpolate(p0.y, p1.y);
		interpolate(p0.z, p1.z);
	}
	void interpolate(RotateX& p0, const RotateX& p1) { interpolate(p0.angle, p1.angle); }
	void interpolate(RotateY& p0, const RotateY& p1) { interpolate(p0.angle, p1.angle); }
	void interpolate(RotateZ& p0, const RotateZ& p1) { interpolate(p0.angle, p1.angle); }
	void interpolate(Rotate2D& p0, const Rotate2D& p1) { interpolate(p0.angle, p1.angle); }
	void interpolate(Rotate3D& p0, const Rotate3D& p1) {
		glm::quat q0(p0.angle.number, p0.axis);
		glm::quat q1(p1.angle.number, p1.axis);
		q0 = glm::slerp(q0, q1, alpha);
		p0.axis = glm::axis(q0);
		p0.angle.number = glm::angle(q0);
	}
	void interpolate(SkewX& p0, const SkewX& p1) { interpolate(p0.x, p1.x); }
	void interpolate(SkewY& p0, const SkewY& p1) { interpolate(p0.y, p1.y); }
	void interpolate(Skew2D& p0, const Skew2D& p1) { interpolate(p0.x, p1.x); interpolate(p0.y, p1.y); }
};

struct ToStringVisitor {
	String operator()(const Transforms::SkewX& p) {
		return "skewX(" + ToString(p.x) + ")";
	}
	String operator()(const Transforms::SkewY& p) {
		return "skewY(" + ToString(p.y) + ")";
	}
	String operator()(const Transforms::Skew2D& p) {
		return "skew(" + ToString(p.x) + "," + ToString(p.y) + ")";
	}
	String operator()(const Transforms::RotateX& p) {
		return "rotateX(" + ToString(p.angle) + ")";
	}
	String operator()(const Transforms::RotateY& p) {
		return "rotateY(" + ToString(p.angle) + ")";
	}
	String operator()(const Transforms::RotateZ& p) {
		return "rotateZ(" + ToString(p.angle) + ")";
	}
	String operator()(const Transforms::Rotate2D& p) {
		return "rotate(" + ToString(p.angle) + ")";
	}
	String operator()(const Transforms::Rotate3D& p) {
		return "rotate3d("
			+ ToString(p.axis.x) + ","
			+ ToString(p.axis.y) + ","
			+ ToString(p.axis.z) + ","
			+ ToString(p.angle)
			+ ")";
	}
	String operator()(const Transforms::ScaleX& p) {
		return "scaleX(" + ToString(p.x) + ")";
	}
	String operator()(const Transforms::ScaleY& p) {
		return "scaleY(" + ToString(p.y) + ")";
	}
	String operator()(const Transforms::ScaleZ& p) {
		return "scaleZ(" + ToString(p.z) + ")";
	}
	String operator()(const Transforms::Scale2D& p) {
		return "scale(" + ToString(p.x) + "," + ToString(p.y) + ")";
	}
	String operator()(const Transforms::Scale3D& p) {
		return "scale3d(" + ToString(p.x) + "," + ToString(p.y) + "," + ToString(p.z) + ")";
	}
	String operator()(const Transforms::TranslateX& p) {
		return "translateX(" + ToString(p.x) + ")";
	}
	String operator()(const Transforms::TranslateY& p) {
		return "translateY(" + ToString(p.y) + ")";
	}
	String operator()(const Transforms::TranslateZ& p) {
		return "translateZ(" + ToString(p.z) + ")";
	}
	String operator()(const Transforms::Translate2D& p) {
		return "translate(" + ToString(p.x) + "," + ToString(p.y) + ")";
	}
	String operator()(const Transforms::Translate3D& p) {
		return "translate3d(" + ToString(p.x) + "," + ToString(p.y) + "," + ToString(p.z) + ")";
	}
	String operator()(const Transforms::Perspective& p) {
		return "perspective(" + ToString(p.distance) + ")";
	}
	String operator()(const Transforms::Matrix2D& p) {
		return "matrix("
			+ ToString(p[0][0]) + "," + ToString(p[0][1]) + ","
			+ ToString(p[1][0]) + "," + ToString(p[1][1]) + ","
			+ ToString(p[2][0]) + "," + ToString(p[2][1])
			+ ")";
	}
	String operator()(const Transforms::Matrix3D& p) {
		return "matrix3d("
			+ ToString(p[0][0]) + "," + ToString(p[0][1]) + "," + ToString(p[0][2]) + "," + ToString(p[0][3]) + ","
			+ ToString(p[1][0]) + "," + ToString(p[1][1]) + "," + ToString(p[1][2]) + "," + ToString(p[1][3]) + ","
			+ ToString(p[2][0]) + "," + ToString(p[2][1]) + "," + ToString(p[2][2]) + "," + ToString(p[2][3]) + ","
			+ ToString(p[3][0]) + "," + ToString(p[3][1]) + "," + ToString(p[3][2]) + "," + ToString(p[3][3])
			+ ")";
	}
	String operator()(const Transforms::DecomposedMatrix4& p) noexcept {
		static const Transforms::DecomposedMatrix4 d{
			glm::vec4(0, 0, 0, 1),
			glm::quat(0, 0, 0, 1),
			glm::vec3(0, 0, 0),
			glm::vec3(1, 1, 1),
			glm::vec3(0, 0, 0)
		};
		String result;
		if (p.perspective != d.perspective)
			result += "perspective(" + glm::to_string(p.perspective) + "), ";
		if (p.quaternion != d.quaternion)
			result += "quaternion(" + glm::to_string(p.quaternion) + "), ";
		if (p.translation != d.translation)
			result += "translation(" + glm::to_string(p.translation) + "), ";
		if (p.scale != d.scale)
			result += "scale(" + glm::to_string(p.scale) + "), ";
		if (p.skew != d.skew)
			result += "skew(" + glm::to_string(p.skew) + "), ";
		return "decomposedMatrix3d{ " + result + " }";
	}
};

struct GetTypeVisitor {
	TransformType operator()(const Transforms::TranslateX&) { return  TransformType::Translate; }
	TransformType operator()(const Transforms::TranslateY&) { return  TransformType::Translate; }
	TransformType operator()(const Transforms::TranslateZ&) { return  TransformType::Translate; }
	TransformType operator()(const Transforms::Translate2D&) { return  TransformType::Translate; }
	TransformType operator()(const Transforms::Translate3D&) { return  TransformType::Translate; }
	TransformType operator()(const Transforms::ScaleX&) { return  TransformType::Scale; }
	TransformType operator()(const Transforms::ScaleY&) { return  TransformType::Scale; }
	TransformType operator()(const Transforms::ScaleZ&) { return  TransformType::Scale; }
	TransformType operator()(const Transforms::Scale2D&) { return  TransformType::Scale; }
	TransformType operator()(const Transforms::Scale3D&) { return  TransformType::Scale; }
	TransformType operator()(const Transforms::RotateX&) { return  TransformType::Rotate; }
	TransformType operator()(const Transforms::RotateY&) { return  TransformType::Rotate; }
	TransformType operator()(const Transforms::RotateZ&) { return  TransformType::Rotate; }
	TransformType operator()(const Transforms::Rotate2D&) { return  TransformType::Rotate; }
	TransformType operator()(const Transforms::Rotate3D&) { return  TransformType::Rotate; }
	TransformType operator()(const Transforms::SkewX&) { return  TransformType::Skew; }
	TransformType operator()(const Transforms::SkewY&) { return  TransformType::Skew; }
	TransformType operator()(const Transforms::Skew2D&) { return  TransformType::Skew; }
	TransformType operator()(const Transforms::Matrix2D&) { return  TransformType::Matrix; }
	TransformType operator()(const Transforms::Matrix3D&) { return  TransformType::Matrix; }
	TransformType operator()(const Transforms::Perspective&) { return  TransformType::Matrix; }
	TransformType operator()(const Transforms::DecomposedMatrix4&) { return  TransformType::Matrix; }
};

struct ConvertToGenericTypeVisitor {
	TransformPrimitive& t;
	template <typename T>
	void operator()(const T& p) { }
	void operator()(const TranslateX& p) { t = Translate3D{ p.x, {}, {} }; }
	void operator()(const TranslateY& p) { t = Translate3D{ {}, p.y, {} }; }
	void operator()(const TranslateZ& p) { t = Translate3D{ {}, {}, p.z }; }
	void operator()(const Translate2D& p) { t = Translate3D{ p.x, p.y, {} }; }
	void operator()(const ScaleX& p) { t = Scale3D{ p.x, {}, {} }; }
	void operator()(const ScaleY& p) { t = Scale3D{ {}, p.y, {} }; }
	void operator()(const ScaleZ& p) { t = Scale3D{ {}, {}, p.z }; }
	void operator()(const Scale2D& p) { t = Scale3D{ p.x, p.y, {} }; }
	void operator()(const RotateX& p) { t = Rotate3D{ {1,0,0}, p.angle }; }
	void operator()(const RotateY& p) { t = Rotate3D{ {0,1,0}, p.angle }; }
	void operator()(const RotateZ& p) { t = Rotate3D{ {0,0,1}, p.angle }; }
	void operator()(const Rotate2D& p) { t = Rotate3D{ {0,0,1}, p.angle }; }
	void operator()(const SkewX& p) { t = Skew2D{ p.x, {} }; }
	void operator()(const SkewY& p) { t = Skew2D{ {}, p.y }; }
};

void TransformPrimitive::SetIdentity() {
	std::visit(SetIdentityVisitor(), *this);
}

bool TransformPrimitive::PrepareForInterpolation(Element& e) {
	PrepareVisitor visitor{ e, *this };
	std::visit(visitor, *this);
	return visitor.ok;
}

void TransformPrimitive::ConvertToGenericType() {
	std::visit(ConvertToGenericTypeVisitor{ *this }, *this);
}

bool TransformPrimitive::Interpolate(const TransformPrimitive& other, float alpha) {
	if (index() != other.index())
		return false;
	return std::visit(InterpolateVisitor{ other, alpha }, *this);
}

String TransformPrimitive::ToString() const {
	return std::visit(ToStringVisitor{}, *this);
}

TransformType TransformPrimitive::GetType() const {
	return std::visit(GetTypeVisitor{}, *this);
}

UniquePtr<Transform> Transform::Interpolate(const Transform& other, float alpha) {
	if (size() != other.size()) {
		return {};
	}
	UniquePtr<Transform> new_transform(new Transform);
	new_transform->reserve(size());
	for (size_t i = 0; i < size(); ++i) {
		TransformPrimitive p = (*this)[i];
		if (!p.Interpolate(other[i], alpha)) {
			return {};
		}
		new_transform->emplace_back(std::move(p));
	}
	return new_transform;
}

glm::mat4x4 Transform::GetMatrix(Element& e) const {
	MultiplyVisitor visitor{ e };
	for (auto const& t : *this) {
		std::visit(visitor, t);
	}
	return visitor.matrix;
}

bool Transform::Combine(Element& e, size_t start) {
	MultiplyVisitor visitor{ e };
	for (size_t i = start; i < size(); ++i) {
		std::visit(visitor, (*this)[i]);
	}
	auto d = decompose(visitor.matrix);
	if (!d) {
		return false;
	}
	erase(begin() + start, end());
	emplace_back(std::move(d.value()));
	return true;
}

}
