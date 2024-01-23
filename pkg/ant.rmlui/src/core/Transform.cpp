#include <core/Transform.h>
#include <core/Element.h>
#include <glm/gtx/transform.hpp>
#include <glm/gtx/string_cast.hpp>
#include <glm/gtx/compatibility.hpp>
#include <glm/gtx/matrix_decompose.hpp>
#include <bee/nonstd/format.h>
#include <optional>

namespace Rml {

using namespace Transforms;

static std::string ToString(const float& v) {
	return std::format("{}", v);
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
		return std::nullopt;
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
		v.x = p.x.ComputeW(&e);
		matrix = glm::translate(matrix, v);
	}
	void operator()(const Transforms::TranslateY& p) {
		glm::vec3 v{ 0 };
		v.y = p.y.ComputeH(&e);
		matrix = glm::translate(matrix, v);
	}
	void operator()(const Transforms::TranslateZ& p) {
		glm::vec3 v{ 0 };
		v.z = p.z.Compute(&e);
		matrix = glm::translate(matrix, v);
	}
	void operator()(const Transforms::Translate2D& p) {
		glm::vec3 v{ 0 };
		v.x = p.x.ComputeW(&e);
		v.y = p.y.ComputeH(&e);
		matrix = glm::translate(matrix, v);
	}
	void operator()(const Transforms::Translate3D& p) {
		glm::vec3 v{ 0 };
		v.x = p.x.ComputeW(&e);
		v.y = p.y.ComputeH(&e);
		v.z = p.z.Compute(&e);
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
		float angle = p.angle.Compute(&e);
		matrix = glm::rotate(matrix, angle, { 1, 0, 0 });
	}
	void operator()(const Transforms::RotateY& p) {
		float angle = p.angle.Compute(&e);
		matrix = glm::rotate(matrix, angle, { 0, 1, 0 });
	}
	void operator()(const Transforms::RotateZ& p) {
		float angle = p.angle.Compute(&e);
		matrix = glm::rotate(matrix, angle, { 0, 0, 1 });
	}
	void operator()(const Transforms::Rotate2D& p) {
		float angle = p.angle.Compute(&e);
		matrix = glm::rotate(matrix, angle, { 0, 0, 1 });
	}
	void operator()(const Transforms::Rotate3D& p) {
		float angle = p.angle.Compute(&e);
		matrix = glm::rotate(matrix, angle, p.axis);
	}
	void operator()(const Transforms::SkewX& p) {
		matrix *= skew(p.x.Compute(&e), 0);
	}
	void operator()(const Transforms::SkewY& p) {
		matrix *= skew(0, p.y.Compute(&e));
	}
	void operator()(const Transforms::Skew2D& p) {
		matrix *= skew(p.x.Compute(&e), p.y.Compute(&e));
	}
	void operator()(const Transforms::DecomposedMatrix4& p) {
		matrix *= compose(p.translation, p.scale, p.skew, p.perspective, p.quaternion);
	}
	void operator()(const Transforms::Perspective& p) {
		float distance = p.distance.Compute(&e);
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
		p.x = { p.x.ComputeW(&e), PropertyUnit::PX };
	}
	void operator()(TranslateY& p) {
		p.y = { p.y.ComputeH(&e), PropertyUnit::PX };
	}
	void operator()(TranslateZ& p) {
		p.z = { p.z.Compute(&e), PropertyUnit::PX };
	}
	void operator()(Translate2D& p) {
		p.x = { p.x.ComputeW(&e), PropertyUnit::PX };
		p.y = { p.y.ComputeH(&e), PropertyUnit::PX };
	}
	void operator()(Translate3D& p) {
		p.x = { p.x.ComputeW(&e), PropertyUnit::PX };
		p.y = { p.y.ComputeH(&e), PropertyUnit::PX };
		p.z = { p.z.Compute(&e), PropertyUnit::PX };
	}
	void operator()(RotateX& p) {
		p.angle = { p.angle.Compute(&e), PropertyUnit::RAD };
	}
	void operator()(RotateY& p) {
		p.angle = { p.angle.Compute(&e), PropertyUnit::RAD };
	}
	void operator()(RotateZ& p) {
		p.angle = { p.angle.Compute(&e), PropertyUnit::RAD };
	}
	void operator()(Rotate2D& p) {
		p.angle = { p.angle.Compute(&e), PropertyUnit::RAD };
	}
	void operator()(Rotate3D& p) {
		p.angle = { p.angle.Compute(&e), PropertyUnit::RAD };
	}
	void operator()(SkewX& p) {
		p.x = { p.x.Compute(&e), PropertyUnit::RAD };
	}
	void operator()(SkewY& p) {
		p.y = { p.y.Compute(&e), PropertyUnit::RAD };
	}
	void operator()(Skew2D& p) {
		p.x = { p.x.Compute(&e), PropertyUnit::RAD };
		p.y = { p.y.Compute(&e), PropertyUnit::RAD };
	}
	void operator()(Matrix3D& p) {
		auto d = decompose((const glm::mat4x4&)p);
		if (d) { t = *d; }
		else { ok = false; };
	}
	void operator()(Matrix2D& p) {
		auto d = decompose(matrix2d((const glm::mat3x2&)p));
		if (d) { t = *d; }
		else { ok = false; };
	}
	void operator()(Perspective& p) {
		float distance = p.distance.Compute(&e);
		auto d = decompose(perspective(distance));
		if (d) { t = *d; }
		else { ok = false; };
	}
};

struct InterpolateVisitor {
	const TransformPrimitive& other_variant;
	float alpha;
	template <typename T>
	Transforms::Primitive operator()(const T& p0) {
		return interpolate(p0, std::get<T>(other_variant));
	}
	float interpolate(const float& p0, const float& p1) const {
		return glm::lerp(p0, p1, alpha);
	}
	Matrix3D interpolate(const Matrix3D& p0, const Matrix3D& p1) const {
		return InterpolateFallback(p0, p1, alpha);
	}
	Matrix2D interpolate(const Matrix2D& p0, const Matrix2D& p1) const {
		return InterpolateFallback(p0, p1, alpha);
	}
	Perspective interpolate(const Perspective& p0, const Perspective& p1) const {
		return InterpolateFallback(p0, p1, alpha);
	}
	PropertyFloat interpolate(const PropertyFloat& p0, const PropertyFloat& p1) const {
		return p0.Interpolate(p1, alpha);
	}
	DecomposedMatrix4 interpolate(const DecomposedMatrix4& p0, const DecomposedMatrix4& p1) const {
		return {
			glm::lerp(p0.perspective, p1.perspective, alpha),
			glm::slerp(p0.quaternion, p1.quaternion, alpha),
			glm::lerp(p0.translation, p1.translation, alpha),
			glm::lerp(p0.scale, p1.scale, alpha),
			glm::lerp(p0.skew, p1.skew, alpha),
		};
	}
	TranslateX interpolate(const TranslateX& p0, const TranslateX& p1) const {
		return { interpolate(p0.x, p1.x) };
	}
	TranslateY interpolate(const TranslateY& p0, const TranslateY& p1) const {
		return { interpolate(p0.y, p1.y) };
	}
	TranslateZ interpolate(const TranslateZ& p0, const TranslateZ& p1) const {
		return { interpolate(p0.z, p1.z) };
	}
	Translate2D interpolate(const Translate2D& p0, const Translate2D& p1) const {
		return {
			interpolate(p0.x, p1.x),
			interpolate(p0.y, p1.y),
		};
	}
	Translate3D interpolate(const Translate3D& p0, const Translate3D& p1) const {
		return {
			interpolate(p0.x, p1.x),
			interpolate(p0.y, p1.y),
			interpolate(p0.z, p1.z),
		};
	}
	ScaleX interpolate(const ScaleX& p0, const ScaleX& p1) const {
		return { interpolate(p0.x, p1.x) };
	}
	ScaleY interpolate(const ScaleY& p0, const ScaleY& p1) const {
		return { interpolate(p0.y, p1.y) };
	}
	ScaleZ interpolate(const ScaleZ& p0, const ScaleZ& p1) const {
		return { interpolate(p0.z, p1.z) };
	}
	Scale2D interpolate(const Scale2D& p0, const Scale2D& p1) const {
		return {
			interpolate(p0.x, p1.x),
			interpolate(p0.y, p1.y),
		};
	}
	Scale3D interpolate(const Scale3D& p0, const Scale3D& p1) const {
		return {
			interpolate(p0.x, p1.x),
			interpolate(p0.y, p1.y),
			interpolate(p0.z, p1.z),
		};
	}
	RotateX interpolate(const RotateX& p0, const RotateX& p1) const {
		return { interpolate(p0.angle, p1.angle) };
	}
	RotateY interpolate(const RotateY& p0, const RotateY& p1) const {
		return { interpolate(p0.angle, p1.angle) };
	}
	RotateZ interpolate(const RotateZ& p0, const RotateZ& p1) const {
		return { interpolate(p0.angle, p1.angle) };
	}
	Rotate2D interpolate(const Rotate2D& p0, const Rotate2D& p1) const {
		return { interpolate(p0.angle, p1.angle) };
	}
	Rotate3D interpolate(const Rotate3D& p0, const Rotate3D& p1) {
		glm::quat q0(p0.angle.ComputeAngle(), p0.axis);
		glm::quat q1(p1.angle.ComputeAngle(), p1.axis);
		glm::quat q2 = glm::slerp(q0, q1, alpha);
		return {
			glm::axis(q2),
			{ glm::angle(q2), PropertyUnit::RAD },
		};
	}
	SkewX interpolate(const SkewX& p0, const SkewX& p1) const {
		return { interpolate(p0.x, p1.x) };
	}
	SkewY interpolate(const SkewY& p0, const SkewY& p1) const {
		return { interpolate(p0.y, p1.y) };
	}
	Skew2D interpolate(const Skew2D& p0, const Skew2D& p1) const {
		return {
			interpolate(p0.x, p1.x),
			interpolate(p0.y, p1.y),
		};
	}
};

struct ToStringVisitor {
	std::string operator()(const Transforms::SkewX& p) {
		return "skewX(" + p.x.ToString() + ")";
	}
	std::string operator()(const Transforms::SkewY& p) {
		return "skewY(" + p.y.ToString() + ")";
	}
	std::string operator()(const Transforms::Skew2D& p) {
		return "skew(" + p.x.ToString() + "," + p.y.ToString() + ")";
	}
	std::string operator()(const Transforms::RotateX& p) {
		return "rotateX(" + p.angle.ToString() + ")";
	}
	std::string operator()(const Transforms::RotateY& p) {
		return "rotateY(" + p.angle.ToString() + ")";
	}
	std::string operator()(const Transforms::RotateZ& p) {
		return "rotateZ(" + p.angle.ToString() + ")";
	}
	std::string operator()(const Transforms::Rotate2D& p) {
		return "rotate(" + p.angle.ToString() + ")";
	}
	std::string operator()(const Transforms::Rotate3D& p) {
		return "rotate3d("
			+ ToString(p.axis.x) + ","
			+ ToString(p.axis.y) + ","
			+ ToString(p.axis.z) + ","
			+ p.angle.ToString()
			+ ")";
	}
	std::string operator()(const Transforms::ScaleX& p) {
		return "scaleX(" + ToString(p.x) + ")";
	}
	std::string operator()(const Transforms::ScaleY& p) {
		return "scaleY(" + ToString(p.y) + ")";
	}
	std::string operator()(const Transforms::ScaleZ& p) {
		return "scaleZ(" + ToString(p.z) + ")";
	}
	std::string operator()(const Transforms::Scale2D& p) {
		return "scale(" + ToString(p.x) + "," + ToString(p.y) + ")";
	}
	std::string operator()(const Transforms::Scale3D& p) {
		return "scale3d(" + ToString(p.x) + "," + ToString(p.y) + "," + ToString(p.z) + ")";
	}
	std::string operator()(const Transforms::TranslateX& p) {
		return "translateX(" + p.x.ToString() + ")";
	}
	std::string operator()(const Transforms::TranslateY& p) {
		return "translateY(" + p.y.ToString() + ")";
	}
	std::string operator()(const Transforms::TranslateZ& p) {
		return "translateZ(" + p.z.ToString() + ")";
	}
	std::string operator()(const Transforms::Translate2D& p) {
		return "translate(" + p.x.ToString() + "," + p.y.ToString() + ")";
	}
	std::string operator()(const Transforms::Translate3D& p) {
		return "translate3d(" + p.x.ToString() + "," + p.y.ToString() + "," + p.z.ToString() + ")";
	}
	std::string operator()(const Transforms::Perspective& p) {
		return "perspective(" + p.distance.ToString() + ")";
	}
	std::string operator()(const Transforms::Matrix2D& p) {
		return "matrix("
			+ ToString(p[0][0]) + "," + ToString(p[0][1]) + ","
			+ ToString(p[1][0]) + "," + ToString(p[1][1]) + ","
			+ ToString(p[2][0]) + "," + ToString(p[2][1])
			+ ")";
	}
	std::string operator()(const Transforms::Matrix3D& p) {
		return "matrix3d("
			+ ToString(p[0][0]) + "," + ToString(p[0][1]) + "," + ToString(p[0][2]) + "," + ToString(p[0][3]) + ","
			+ ToString(p[1][0]) + "," + ToString(p[1][1]) + "," + ToString(p[1][2]) + "," + ToString(p[1][3]) + ","
			+ ToString(p[2][0]) + "," + ToString(p[2][1]) + "," + ToString(p[2][2]) + "," + ToString(p[2][3]) + ","
			+ ToString(p[3][0]) + "," + ToString(p[3][1]) + "," + ToString(p[3][2]) + "," + ToString(p[3][3])
			+ ")";
	}
	std::string operator()(const Transforms::DecomposedMatrix4& p) noexcept {
		static const Transforms::DecomposedMatrix4 d{
			glm::vec4(0, 0, 0, 1),
			glm::quat(0, 0, 0, 1),
			glm::vec3(0, 0, 0),
			glm::vec3(1, 1, 1),
			glm::vec3(0, 0, 0)
		};
		std::string result;
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

static PropertyFloat zero = {0.f, PropertyUnit::NUMBER};

struct ConvertToGenericTypeVisitor {
	TransformPrimitive& t;
	template <typename T>
	void operator()(const T& p) { }
	void operator()(const TranslateX& p) { t = Translate3D{ p.x, zero, zero }; }
	void operator()(const TranslateY& p) { t = Translate3D{ zero, p.y, zero }; }
	void operator()(const TranslateZ& p) { t = Translate3D{ zero, zero, p.z }; }
	void operator()(const Translate2D& p) { t = Translate3D{ p.x, p.y, zero }; }
	void operator()(const ScaleX& p) { t = Scale3D{ p.x, {}, {} }; }
	void operator()(const ScaleY& p) { t = Scale3D{ {}, p.y, {} }; }
	void operator()(const ScaleZ& p) { t = Scale3D{ {}, {}, p.z }; }
	void operator()(const Scale2D& p) { t = Scale3D{ p.x, p.y, {} }; }
	void operator()(const RotateX& p) { t = Rotate3D{ {1,0,0}, p.angle }; }
	void operator()(const RotateY& p) { t = Rotate3D{ {0,1,0}, p.angle }; }
	void operator()(const RotateZ& p) { t = Rotate3D{ {0,0,1}, p.angle }; }
	void operator()(const Rotate2D& p) { t = Rotate3D{ {0,0,1}, p.angle }; }
	void operator()(const SkewX& p) { t = Skew2D{ p.x, zero }; }
	void operator()(const SkewY& p) { t = Skew2D{ zero, p.y }; }
};

void TransformPrimitive::SetIdentity() {
	std::visit(SetIdentityVisitor(), static_cast<Transforms::Primitive&>(*this));
}

bool TransformPrimitive::PrepareInterpolate(Element& e) {
	PrepareVisitor visitor{ e, *this };
	std::visit(visitor, static_cast<Transforms::Primitive&>(*this));
	return visitor.ok;
}

void TransformPrimitive::ConvertToGenericType() {
	std::visit(ConvertToGenericTypeVisitor{ *this }, static_cast<Transforms::Primitive&>(*this));
}

TransformPrimitive TransformPrimitive::Interpolate(const TransformPrimitive& other, float alpha) const {
	if (index() != other.index()) {
		return InterpolateFallback(*this, other, alpha);
	}
	return std::visit(InterpolateVisitor{ other, alpha }, static_cast<const Transforms::Primitive&>(*this));
}

std::string TransformPrimitive::ToString() const {
	return std::visit(ToStringVisitor{}, static_cast<Transforms::Primitive const&>(*this));
}

TransformType TransformPrimitive::GetType() const {
	return std::visit(GetTypeVisitor{}, static_cast<Transforms::Primitive const&>(*this));
}

bool Transform::PrepareInterpolate(Element& e) {
	for (auto& p0 : *this) {
		if (!p0.PrepareInterpolate(e)) {
			return false;
		}
	}
	return true;
}

Transform Transform::Interpolate(const Transform& other, float alpha) const {
	if (size() != other.size()) {
		return InterpolateFallback(*this, other, alpha);
	}
	Transform new_transform {};
	new_transform.reserve(size());
	for (size_t i = 0; i < size(); ++i) {
		auto const& p = (*this)[i];
		new_transform.emplace_back(p.Interpolate(other[i], alpha));
	}
	return new_transform;
}

glm::mat4x4 Transform::GetMatrix(Element& e) const {
	MultiplyVisitor visitor{ e };
	for (auto const& t : *this) {
		std::visit(visitor, static_cast<Transforms::Primitive const&>(t));
	}
	return visitor.matrix;
}

bool Transform::Combine(Element& e, size_t start) {
	MultiplyVisitor visitor{ e };
	for (size_t i = start; i < size(); ++i) {
		std::visit(visitor, static_cast<Transforms::Primitive&>((*this)[i]));
	}
	auto d = decompose(visitor.matrix);
	if (!d) {
		return false;
	}
	erase(begin() + start, end());
	emplace_back(std::move(*d));
	return true;
}

std::string Transform::ToString() const {
	std::string result;
	for (auto const& t : *this) {
		if (!result.empty()) {
			result += ", ";
		}
		result += t.ToString();
	}
	return result;
}


//
// see
//   https://www.w3.org/TR/css-transforms-1/#interpolation-of-transforms
//   https://www.w3.org/TR/css-transforms-2/#interpolation-of-transform-functions
//
PrepareResult PrepareTransformPair(Transform& t0, Transform& t1, Element& element) {
	if (!t0.PrepareInterpolate(element)) {
		return PrepareResult::Failed;
	}
	if (!t1.PrepareInterpolate(element)) {
		return PrepareResult::Failed;
	}
	if (t0.size() != t1.size()) {
		bool t0_shorter = t0.size() < t1.size();
		auto& shorter = t0_shorter ? t0 : t1;
		auto& longer = t0_shorter ? t1 : t0;
		bool changed_longer = false;
		size_t i = 0;
		for (; i < shorter.size(); ++i) {
			auto& p0 = shorter[i];
			auto& p1 = longer[i];
			if (p0.index() == p1.index()) {
				continue;
			}
			if (p0.GetType() == p1.GetType()) {
				p0.ConvertToGenericType();
				p1.ConvertToGenericType();
				assert(p0.index() == p1.index());
				changed_longer = true;
				continue;
			}
			if (t0.Combine(element, i) && t1.Combine(element, i)) {
				return PrepareResult::ChangedAll;
			}
			else {
				return PrepareResult::Failed;
			}
		}
		for (; i < longer.size(); ++i) {
			auto& p1 = longer[i];
			TransformPrimitive p = p1;
			p.SetIdentity();
			shorter.insert(shorter.begin() + i, p);
		}
		if (changed_longer) {
			return PrepareResult::ChangedAll;
		}
		if (t0_shorter) {
			return PrepareResult::ChangedT0;
		}
		else {
			return PrepareResult::ChangedT1;
		}
	}
	for (size_t i = 0; i < t0.size(); ++i) {
		if (t0[i].index() != t1[i].index()) {
			if (t0.Combine(element, i) && t1.Combine(element, i)) {
				return PrepareResult::ChangedAll;
			}
			else {
				return PrepareResult::Failed;
			}
		}
	}
	return PrepareResult::NoChanged;
}

}
