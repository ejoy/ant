/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2014 Markus Schöngart
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

#include "TransformUtilities.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/TransformPrimitive.h"
#include "../Include/RmlUi/Math.h"
#include <glm/gtx/transform.hpp>
#include <glm/gtx/matrix_decompose.hpp>
#include <glm/gtx/string_cast.hpp>

namespace Rml {

using namespace Transforms;

/// Resolve a numeric property value for an element.
static inline float ResolveLengthPercentage(NumericValue value, Element& e, float base) noexcept
{
	Property prop;
	prop.value = Variant(value.number);
	prop.unit = value.unit;
	return e.ResolveNumericProperty(&prop, base);
}

/// Resolve a numeric property value with the element's width as relative base value.
static inline float ResolveWidth(NumericValue value, Element& e) noexcept
{
	if (value.unit & (Property::PX | Property::NUMBER)) return value.number;
	return ResolveLengthPercentage(value, e, e.GetMetrics().frame.size.w);
}

/// Resolve a numeric property value with the element's height as relative base value.
static inline float ResolveHeight(NumericValue value, Element& e) noexcept
{
	if (value.unit & (Property::PX | Property::NUMBER)) return value.number;
	return ResolveLengthPercentage(value, e, e.GetMetrics().frame.size.h);
}

/// Resolve a numeric property value with the element's depth as relative base value.
static inline float ResolveDepth(NumericValue value, Element& e) noexcept
{
	if (value.unit & (Property::PX | Property::NUMBER)) return value.number;
	Size size = e.GetMetrics().frame.size;
	return ResolveLengthPercentage(value, e, Math::Max(size.w, size.h));
}

static inline String ToString(NumericValue value) noexcept
{
	Property prop;
	prop.value = Variant(value.number);
	prop.unit = value.unit;
	return prop.ToString();
}

struct SetIdentityVisitor
{
	template <size_t N>
	void operator()(Transforms::ResolvedPrimitive<N>& p)
	{
		for (auto& value : p.values)
			value = 0.0f;
	}
	template <size_t N>
	void operator()(Transforms::UnresolvedPrimitive<N>& p)
	{
		for (auto& value : p.values)
			value.number = 0.0f;
	}
	void operator()(Transforms::Matrix2D& p)
	{
		for (int i = 0; i < 6; i++)
			p.values[i] = ((i == 0 || i == 3) ? 1.0f : 0.0f);
	}
	void operator()(Transforms::Matrix3D& p)
	{
		for (int i = 0; i < 16; i++)
			p.values[i] = ((i % 5) == 0 ? 1.0f : 0.0f);
	}
	void operator()(Transforms::ScaleX& p)
	{
		p.values[0] = 1;
	}
	void operator()(Transforms::ScaleY& p)
	{
		p.values[0] = 1;
	}
	void operator()(Transforms::ScaleZ& p)
	{
		p.values[0] = 1;
	}
	void operator()(Transforms::Scale2D& p)
	{
		p.values[0] = p.values[1] = 1;
	}
	void operator()(Transforms::Scale3D& p)
	{
		p.values[0] = p.values[1] = p.values[2] = 1;
	}
	void operator()(Transforms::DecomposedMatrix4& p)
	{
		p.perspective = glm::vec4(0, 0, 0, 1);
		p.quaternion = glm::quat(0, 0, 0, 1);
		p.translation = glm::vec3(0, 0, 0);
		p.scale = glm::vec3(1, 1, 1);
		p.skew = glm::vec3(0, 0, 0);
	}


	void run(TransformPrimitive& primitive)
	{
		switch (primitive.type)
		{
		case TransformPrimitive::MATRIX2D: this->operator()(primitive.matrix_2d); break;
		case TransformPrimitive::MATRIX3D: this->operator()(primitive.matrix_3d); break;
		case TransformPrimitive::TRANSLATEX: this->operator()(primitive.translate_x); break;
		case TransformPrimitive::TRANSLATEY: this->operator()(primitive.translate_y); break;
		case TransformPrimitive::TRANSLATEZ: this->operator()(primitive.translate_z); break;
		case TransformPrimitive::TRANSLATE2D: this->operator()(primitive.translate_2d); break;
		case TransformPrimitive::TRANSLATE3D: this->operator()(primitive.translate_3d); break;
		case TransformPrimitive::SCALEX: this->operator()(primitive.scale_x); break;
		case TransformPrimitive::SCALEY: this->operator()(primitive.scale_y); break;
		case TransformPrimitive::SCALEZ: this->operator()(primitive.scale_z); break;
		case TransformPrimitive::SCALE2D: this->operator()(primitive.scale_2d); break;
		case TransformPrimitive::SCALE3D: this->operator()(primitive.scale_3d); break;
		case TransformPrimitive::ROTATEX: this->operator()(primitive.rotate_x); break;
		case TransformPrimitive::ROTATEY: this->operator()(primitive.rotate_y); break;
		case TransformPrimitive::ROTATEZ: this->operator()(primitive.rotate_z); break;
		case TransformPrimitive::ROTATE2D: this->operator()(primitive.rotate_2d); break;
		case TransformPrimitive::ROTATE3D: this->operator()(primitive.rotate_3d); break;
		case TransformPrimitive::SKEWX: this->operator()(primitive.skew_x); break;
		case TransformPrimitive::SKEWY: this->operator()(primitive.skew_y); break;
		case TransformPrimitive::SKEW2D: this->operator()(primitive.skew_2d); break;
		case TransformPrimitive::PERSPECTIVE: this->operator()(primitive.perspective); break;
		case TransformPrimitive::DECOMPOSEDMATRIX4: this->operator()(primitive.decomposed_matrix_4); break;
		default:
			RMLUI_ASSERT(false);
			break;
		}
	}
};

static glm::mat4x4 skew(float angle_x, float angle_y) {
	float skewX = tanf(angle_x);
	float skewY = tanf(angle_y);
	return glm::mat4x4 {
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

	float x = quaternion.x;
	float y = quaternion.y;
	float z = quaternion.z;
	float w = quaternion.w;
	matrix *=  glm::mat4x4 {
		{ 1.f - 2.f * (y * y + z * z), 2.f * (x * y - z * w), 2.f * (x * z + y * w), 0.f },
		{ 2.f * (x * y + z * w), 1.f - 2.f * (x * x + z * z), 2.f * (y * z - x * w), 0.f },
		{ 2.f * (x * z - y * w), 2.f * (y * z + x * w), 1.f - 2.f * (x * x + y * y), 0.f },
		{ 0, 0, 0, 1 }
	};

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

void TransformUtilities::SetIdentity(TransformPrimitive& p) noexcept
{
	SetIdentityVisitor{}.run(p);
}


struct ResolveTransformVisitor
{
	glm::mat4x4& m;
	Element& e;

	void operator()(const Transforms::Matrix2D& p)
	{
		m = glm::mat4x4 {
			{ p.values[0], p.values[2], 0, p.values[4] },
			{ p.values[1], p.values[3], 0, p.values[5] },
			{ 0, 0, 1, 0},
			{ 0, 0, 0, 1}
		};
	}

	void operator()(const Transforms::Matrix3D& p)
	{
		m = glm::mat4x4 {
			{ p.values[0], p.values[1], p.values[2], p.values[3] },
			{ p.values[4], p.values[5], p.values[6], p.values[7] },
			{ p.values[8], p.values[9], p.values[10], p.values[11] },
			{ p.values[12], p.values[13], p.values[14], p.values[15] }
		};
	}

	void operator()(const Transforms::TranslateX& p)
	{
		float x = ResolveWidth(p.values[0], e);
		m = glm::translate(glm::vec3(x, 0, 0));
	}

	void operator()(const Transforms::TranslateY& p)
	{
		float y = ResolveHeight(p.values[0], e);
		m = glm::translate(glm::vec3(0, y, 0));
	}

	void operator()(const Transforms::TranslateZ& p)
	{
		float z = ResolveDepth(p.values[0], e);
		m = glm::translate(glm::vec3(0, 0, z));
	}

	void operator()(const Transforms::Translate2D& p)
	{
		float x = ResolveWidth(p.values[0], e);
		float y = ResolveHeight(p.values[1], e);
		m = glm::translate(glm::vec3(x, y, 0));
	}

	void operator()(const Transforms::Translate3D& p)
	{
		float x = ResolveWidth(p.values[0], e);
		float y = ResolveHeight(p.values[1], e);
		float z = ResolveDepth(p.values[2], e);
		m = glm::translate(glm::vec3(x, y, z));
	}

	void operator()(const Transforms::ScaleX& p)
	{
		float x = p.values[0];
		m = glm::scale(glm::vec3(x, 1, 1));
	}

	void operator()(const Transforms::ScaleY& p)
	{
		float y = p.values[0];
		m = glm::scale(glm::vec3(1, y, 1));
	}

	void operator()(const Transforms::ScaleZ& p)
	{
		float z = p.values[0];
		m = glm::scale(glm::vec3(1, 1, z));
	}

	void operator()(const Transforms::Scale2D& p)
	{
		float x = p.values[0];
		float y = p.values[1];
		m = glm::scale(glm::vec3(x, y, 1));
	}

	void operator()(const Transforms::Scale3D& p)
	{
		float x = p.values[0];
		float y = p.values[1];
		float z = p.values[2];
		m = glm::scale(glm::vec3(x, y, z));
	}

	void operator()(const Transforms::RotateX& p)
	{
		float angle = p.values[0];
		m = glm::rotate(angle, glm::vec3(1, 0, 0));
	}

	void operator()(const Transforms::RotateY& p)
	{
		float angle = p.values[0];
		m = glm::rotate(angle, glm::vec3(0, 1, 0));
	}

	void operator()(const Transforms::RotateZ& p)
	{
		float angle = p.values[0];
		m = glm::rotate(angle, glm::vec3(0, 0, 1));
	}

	void operator()(const Transforms::Rotate2D& p)
	{
		float angle = p.values[0];
		m = glm::rotate(angle, glm::vec3(0, 0, 1));
	}

	void operator()(const Transforms::Rotate3D& p)
	{
		float x = p.values[0];
		float y = p.values[1];
		float z = p.values[2];
		float angle = p.values[3];
		m = glm::rotate(angle, glm::vec3(x, y, z));
	}

	void operator()(const Transforms::SkewX& p)
	{
		m = skew(p.values[0], 0);
	}

	void operator()(const Transforms::SkewY& p)
	{
		m = skew(0, p.values[0]);
	}

	void operator()(const Transforms::Skew2D& p)
	{
		m = skew(p.values[0], p.values[1]);
	}

	void operator()(const Transforms::DecomposedMatrix4& p)
	{
		m = compose(p.translation, p.scale, p.skew, p.perspective, p.quaternion);
	}

	void operator()(const Transforms::Perspective& p)
	{
		float distance = ResolveDepth(p.values[0], e);
		m = glm::mat4x4 {
			{ 1, 0, 0, 0 },
			{ 0, 1, 0, 0 },
			{ 0, 0, 1, 0 },
			{ 0, 0, - 1.f / distance, 1 }
		};
	}

	void run(const TransformPrimitive& primitive)
	{
		switch (primitive.type)
		{
		case TransformPrimitive::MATRIX2D: this->operator()(primitive.matrix_2d); break;
		case TransformPrimitive::MATRIX3D: this->operator()(primitive.matrix_3d); break;
		case TransformPrimitive::TRANSLATEX: this->operator()(primitive.translate_x); break;
		case TransformPrimitive::TRANSLATEY: this->operator()(primitive.translate_y); break;
		case TransformPrimitive::TRANSLATEZ: this->operator()(primitive.translate_z); break;
		case TransformPrimitive::TRANSLATE2D: this->operator()(primitive.translate_2d); break;
		case TransformPrimitive::TRANSLATE3D: this->operator()(primitive.translate_3d); break;
		case TransformPrimitive::SCALEX: this->operator()(primitive.scale_x); break;
		case TransformPrimitive::SCALEY: this->operator()(primitive.scale_y); break;
		case TransformPrimitive::SCALEZ: this->operator()(primitive.scale_z); break;
		case TransformPrimitive::SCALE2D: this->operator()(primitive.scale_2d); break;
		case TransformPrimitive::SCALE3D: this->operator()(primitive.scale_3d); break;
		case TransformPrimitive::ROTATEX: this->operator()(primitive.rotate_x); break;
		case TransformPrimitive::ROTATEY: this->operator()(primitive.rotate_y); break;
		case TransformPrimitive::ROTATEZ: this->operator()(primitive.rotate_z); break;
		case TransformPrimitive::ROTATE2D: this->operator()(primitive.rotate_2d); break;
		case TransformPrimitive::ROTATE3D: this->operator()(primitive.rotate_3d); break;
		case TransformPrimitive::SKEWX: this->operator()(primitive.skew_x); break;
		case TransformPrimitive::SKEWY: this->operator()(primitive.skew_y); break;
		case TransformPrimitive::SKEW2D: this->operator()(primitive.skew_2d); break;
		case TransformPrimitive::PERSPECTIVE: this->operator()(primitive.perspective); break;
		case TransformPrimitive::DECOMPOSEDMATRIX4: this->operator()(primitive.decomposed_matrix_4); break;
		}
	}
};

glm::mat4x4 TransformUtilities::ResolveTransform(const TransformPrimitive& p, Element& e) noexcept
{
	glm::mat4x4 m;
	ResolveTransformVisitor visitor{ m, e };
	visitor.run(p);
	return m;
}

struct PrepareVisitor
{
	Element& e;

	bool operator()(TranslateX& p)
	{
		p.values[0] = NumericValue{ ResolveWidth(p.values[0], e), Property::PX };
		return true;
	}
	bool operator()(TranslateY& p)
	{
		p.values[0] = NumericValue{ ResolveHeight(p.values[0], e), Property::PX };
		return true;
	}
	bool operator()(TranslateZ& p)
	{
		p.values[0] = NumericValue{ ResolveDepth(p.values[0], e), Property::PX };
		return true;
	}
	bool operator()(Translate2D& p)
	{
		p.values[0] = NumericValue{ ResolveWidth(p.values[0], e), Property::PX };
		p.values[1] = NumericValue{ ResolveHeight(p.values[1], e), Property::PX };
		return true;
	}
	bool operator()(Translate3D& p)
	{
		p.values[0] = NumericValue{ ResolveWidth(p.values[0], e), Property::PX };
		p.values[1] = NumericValue{ ResolveHeight(p.values[1], e), Property::PX };
		p.values[2] = NumericValue{ ResolveDepth(p.values[2], e), Property::PX };
		return true;
	}
	template <size_t N>
	bool operator()(ResolvedPrimitive<N>& /*p*/)
	{
		// No conversion needed for resolved transforms (with some exceptions below)
		return true;
	}
	bool operator()(DecomposedMatrix4& /*p*/)
	{
		return true;
	}
	bool operator()(Rotate3D& p)
	{
		// Rotate3D can be interpolated if and only if their rotation axes point in the same direction.
		// We normalize the rotation vector here for easy comparison, and return true here. Later on we make the
		// pair-wise check in 'TryConvertToMatchingGenericType' to see if we need to decompose.
		glm::vec3 vec = glm::normalize(glm::vec3(p.values[0], p.values[1], p.values[2]));
		p.values[0] = vec.x;
		p.values[1] = vec.y;
		p.values[2] = vec.z;
		return true;
	}
	bool operator()(Matrix3D& /*p*/)
	{
		// Matrices must be decomposed for interpolation
		return false;
	}
	bool operator()(Matrix2D& /*p*/)
	{
		// Matrix2D can also be optimized for interpolation, but for now we decompose it to a full DecomposedMatrix4
		return false;
	}
	bool operator()(Perspective& /*p*/)
	{
		// Perspective must be decomposed
		return false;
	}

	bool run(TransformPrimitive& primitive)
	{
		switch (primitive.type)
		{
		case TransformPrimitive::MATRIX2D: return this->operator()(primitive.matrix_2d);
		case TransformPrimitive::MATRIX3D: return this->operator()(primitive.matrix_3d);
		case TransformPrimitive::TRANSLATEX: return this->operator()(primitive.translate_x);
		case TransformPrimitive::TRANSLATEY: return this->operator()(primitive.translate_y);
		case TransformPrimitive::TRANSLATEZ: return this->operator()(primitive.translate_z);
		case TransformPrimitive::TRANSLATE2D: return this->operator()(primitive.translate_2d);
		case TransformPrimitive::TRANSLATE3D: return this->operator()(primitive.translate_3d);
		case TransformPrimitive::SCALEX: return this->operator()(primitive.scale_x);
		case TransformPrimitive::SCALEY: return this->operator()(primitive.scale_y);
		case TransformPrimitive::SCALEZ: return this->operator()(primitive.scale_z);
		case TransformPrimitive::SCALE2D: return this->operator()(primitive.scale_2d);
		case TransformPrimitive::SCALE3D: return this->operator()(primitive.scale_3d);
		case TransformPrimitive::ROTATEX: return this->operator()(primitive.rotate_x);
		case TransformPrimitive::ROTATEY: return this->operator()(primitive.rotate_y);
		case TransformPrimitive::ROTATEZ: return this->operator()(primitive.rotate_z);
		case TransformPrimitive::ROTATE2D: return this->operator()(primitive.rotate_2d);
		case TransformPrimitive::ROTATE3D: return this->operator()(primitive.rotate_3d);
		case TransformPrimitive::SKEWX: return this->operator()(primitive.skew_x);
		case TransformPrimitive::SKEWY: return this->operator()(primitive.skew_y);
		case TransformPrimitive::SKEW2D: return this->operator()(primitive.skew_2d);
		case TransformPrimitive::PERSPECTIVE: return this->operator()(primitive.perspective);
		case TransformPrimitive::DECOMPOSEDMATRIX4: return this->operator()(primitive.decomposed_matrix_4);
		default:
			break;
		}
		RMLUI_ASSERT(false);
		return false;
	}
};

bool TransformUtilities::PrepareForInterpolation(TransformPrimitive& p, Element& e) noexcept
{
	return PrepareVisitor{ e }.run(p);
}

enum class GenericType { None, Scale3D, Translate3D, Rotate3D };

struct GetGenericTypeVisitor
{
	GenericType run(const TransformPrimitive& primitive)
	{
		switch (primitive.type)
		{
		case TransformPrimitive::TRANSLATEX:  return GenericType::Translate3D;
		case TransformPrimitive::TRANSLATEY:  return GenericType::Translate3D;
		case TransformPrimitive::TRANSLATEZ:  return GenericType::Translate3D;
		case TransformPrimitive::TRANSLATE2D: return GenericType::Translate3D;
		case TransformPrimitive::TRANSLATE3D: return GenericType::Translate3D;
		case TransformPrimitive::SCALEX:      return GenericType::Scale3D;
		case TransformPrimitive::SCALEY:      return GenericType::Scale3D;
		case TransformPrimitive::SCALEZ:      return GenericType::Scale3D;
		case TransformPrimitive::SCALE2D:     return GenericType::Scale3D;
		case TransformPrimitive::SCALE3D:     return GenericType::Scale3D;
		case TransformPrimitive::ROTATEX:     return GenericType::Rotate3D;
		case TransformPrimitive::ROTATEY:     return GenericType::Rotate3D;
		case TransformPrimitive::ROTATEZ:     return GenericType::Rotate3D;
		case TransformPrimitive::ROTATE2D:    return GenericType::Rotate3D;
		case TransformPrimitive::ROTATE3D:    return GenericType::Rotate3D;
		default:
			break;
		}
		return GenericType::None;
	}
};


struct ConvertToGenericTypeVisitor
{
	Translate3D operator()(const TranslateX& p) { return Translate3D{ p.values[0], {0.0f, Property::PX}, {0.0f, Property::PX} }; }
	Translate3D operator()(const TranslateY& p) { return Translate3D{ {0.0f, Property::PX}, p.values[0], {0.0f, Property::PX} }; }
	Translate3D operator()(const TranslateZ& p) { return Translate3D{ {0.0f, Property::PX}, {0.0f, Property::PX}, p.values[0] }; }
	Translate3D operator()(const Translate2D& p) { return Translate3D{ p.values[0], p.values[1], {0.0f, Property::PX} }; }
	Scale3D operator()(const ScaleX& p) { return Scale3D{ p.values[0], 1.0f, 1.0f }; }
	Scale3D operator()(const ScaleY& p) { return Scale3D{ 1.0f, p.values[0], 1.0f }; }
	Scale3D operator()(const ScaleZ& p) { return Scale3D{ 1.0f, 1.0f, p.values[0] }; }
	Scale3D operator()(const Scale2D& p) { return Scale3D{ p.values[0], p.values[1], 1.0f }; }
	Rotate3D operator()(const RotateX& p) { return Rotate3D{ 1, 0, 0, p.values[0], Property::RAD }; }
	Rotate3D operator()(const RotateY& p) { return Rotate3D{ 0, 1, 0, p.values[0], Property::RAD }; }
	Rotate3D operator()(const RotateZ& p) { return Rotate3D{ 0, 0, 1, p.values[0], Property::RAD }; }
	Rotate3D operator()(const Rotate2D& p) { return Rotate3D{ 0, 0, 1, p.values[0], Property::RAD }; }

	template <typename T>
	TransformPrimitive operator()(const T& p) { RMLUI_ERROR; return p; }

	TransformPrimitive run(const TransformPrimitive& primitive)
	{
		TransformPrimitive result = primitive;
		switch (primitive.type)
		{
		case TransformPrimitive::TRANSLATEX:  result.type = TransformPrimitive::TRANSLATE3D; result.translate_3d = this->operator()(primitive.translate_x);  break;
		case TransformPrimitive::TRANSLATEY:  result.type = TransformPrimitive::TRANSLATE3D; result.translate_3d = this->operator()(primitive.translate_y);  break;
		case TransformPrimitive::TRANSLATEZ:  result.type = TransformPrimitive::TRANSLATE3D; result.translate_3d = this->operator()(primitive.translate_z);  break;
		case TransformPrimitive::TRANSLATE2D: result.type = TransformPrimitive::TRANSLATE3D; result.translate_3d = this->operator()(primitive.translate_2d); break;
		case TransformPrimitive::TRANSLATE3D: break;
		case TransformPrimitive::SCALEX:      result.type = TransformPrimitive::SCALE3D;     result.scale_3d = this->operator()(primitive.scale_x);      break;
		case TransformPrimitive::SCALEY:      result.type = TransformPrimitive::SCALE3D;     result.scale_3d = this->operator()(primitive.scale_y);      break;
		case TransformPrimitive::SCALEZ:      result.type = TransformPrimitive::SCALE3D;     result.scale_3d = this->operator()(primitive.scale_z);      break;
		case TransformPrimitive::SCALE2D:     result.type = TransformPrimitive::SCALE3D;     result.scale_3d = this->operator()(primitive.scale_2d);     break;
		case TransformPrimitive::SCALE3D:     break;
		case TransformPrimitive::ROTATEX:     result.type = TransformPrimitive::ROTATE3D;    result.rotate_3d = this->operator()(primitive.rotate_x);     break;
		case TransformPrimitive::ROTATEY:     result.type = TransformPrimitive::ROTATE3D;    result.rotate_3d = this->operator()(primitive.rotate_y);     break;
		case TransformPrimitive::ROTATEZ:     result.type = TransformPrimitive::ROTATE3D;    result.rotate_3d = this->operator()(primitive.rotate_z);     break;
		case TransformPrimitive::ROTATE2D:    result.type = TransformPrimitive::ROTATE3D;    result.rotate_3d = this->operator()(primitive.rotate_2d);    break;
		case TransformPrimitive::ROTATE3D:    break;
		default:
			RMLUI_ASSERT(false);
			break;
		}
		return result;
	}
};

static bool CanInterpolateRotate3D(const Rotate3D& p0, const Rotate3D& p1)
{
	// Rotate3D can only be interpolated if and only if their rotation axes point in the same direction.
	// Assumes each rotation axis has already been normalized.
	auto& v0 = p0.values;
	auto& v1 = p1.values;
	return v0[0] == v1[0] && v0[1] == v1[1] && v0[2] == v1[2];
}


bool TransformUtilities::TryConvertToMatchingGenericType(TransformPrimitive& p0, TransformPrimitive& p1) noexcept
{
	if (p0.type == p1.type)
	{
		if (p0.type == TransformPrimitive::ROTATE3D && !CanInterpolateRotate3D(p0.rotate_3d, p1.rotate_3d))
			return false;

		return true;
	}

	GenericType c0 = GetGenericTypeVisitor{}.run(p0);
	GenericType c1 = GetGenericTypeVisitor{}.run(p1);

	if (c0 == c1 && c0 != GenericType::None)
	{
		TransformPrimitive new_p0 = ConvertToGenericTypeVisitor{}.run(p0);
		TransformPrimitive new_p1 = ConvertToGenericTypeVisitor{}.run(p1);

		RMLUI_ASSERT(new_p0.type == new_p1.type);

		if (new_p0.type == TransformPrimitive::ROTATE3D && !CanInterpolateRotate3D(new_p0.rotate_3d, new_p1.rotate_3d))
			return false;

		p0 = new_p0;
		p1 = new_p1;

		return true;
	}

	return false;
}





struct InterpolateVisitor
{
	const TransformPrimitive& other_variant;
	float alpha;

	template <size_t N>
	bool Interpolate(ResolvedPrimitive<N>& p0, const ResolvedPrimitive<N>& p1)
	{
		for (size_t i = 0; i < N; i++)
			p0.values[i] = p0.values[i] * (1.0f - alpha) + p1.values[i] * alpha;
		return true;
	}
	template <size_t N>
	bool Interpolate(UnresolvedPrimitive<N>& p0, const UnresolvedPrimitive<N>& p1)
	{
		// Assumes that the underlying units have been resolved (e.g. to pixels)
		for (size_t i = 0; i < N; i++)
			p0.values[i].number = p0.values[i].number * (1.0f - alpha) + p1.values[i].number * alpha;
		return true;
	}
	bool Interpolate(Rotate3D& p0, const Rotate3D& p1)
	{
		RMLUI_ASSERT(CanInterpolateRotate3D(p0, p1));
		// We can only interpolate rotate3d if their rotation axes align. That should be the case if we get here, 
		// otherwise the generic type matching should decompose them. Thus, we only need to interpolate
		// the angle value here.
		p0.values[3] = p0.values[3] * (1.0f - alpha) + p1.values[3] * alpha;
		return true;
	}
	bool Interpolate(Matrix2D& /*p0*/, const Matrix2D& /*p1*/) { RMLUI_ERROR; return false; /* Error if we get here, see PrepareForInterpolation() */ }
	bool Interpolate(Matrix3D& /*p0*/, const Matrix3D& /*p1*/) { RMLUI_ERROR; return false; /* Error if we get here, see PrepareForInterpolation() */ }
	bool Interpolate(Perspective& /*p0*/, const Perspective& /*p1*/) { RMLUI_ERROR; return false; /* Error if we get here, see PrepareForInterpolation() */ }

	bool Interpolate(DecomposedMatrix4& p0, const DecomposedMatrix4& p1)
	{
		p0.perspective = p0.perspective * (1.0f - alpha) + p1.perspective * alpha;
		p0.quaternion = glm::slerp(p0.quaternion, p1.quaternion, alpha);
		p0.translation = p0.translation * (1.0f - alpha) + p1.translation * alpha;
		p0.scale = p0.scale * (1.0f - alpha) + p1.scale * alpha;
		p0.skew = p0.skew * (1.0f - alpha) + p1.skew * alpha;
		return true;
	}

	bool run(TransformPrimitive& variant)
	{
		RMLUI_ASSERT(variant.type == other_variant.type);
		switch (variant.type)
		{
		case TransformPrimitive::MATRIX2D: return Interpolate(variant.matrix_2d, other_variant.matrix_2d);
		case TransformPrimitive::MATRIX3D: return Interpolate(variant.matrix_3d, other_variant.matrix_3d);
		case TransformPrimitive::TRANSLATEX: return Interpolate(variant.translate_x, other_variant.translate_x);
		case TransformPrimitive::TRANSLATEY: return Interpolate(variant.translate_y, other_variant.translate_y);
		case TransformPrimitive::TRANSLATEZ: return Interpolate(variant.translate_z, other_variant.translate_z);
		case TransformPrimitive::TRANSLATE2D: return Interpolate(variant.translate_2d, other_variant.translate_2d);
		case TransformPrimitive::TRANSLATE3D: return Interpolate(variant.translate_3d, other_variant.translate_3d);
		case TransformPrimitive::SCALEX: return Interpolate(variant.scale_x, other_variant.scale_x);
		case TransformPrimitive::SCALEY: return Interpolate(variant.scale_y, other_variant.scale_y);
		case TransformPrimitive::SCALEZ: return Interpolate(variant.scale_z, other_variant.scale_z);
		case TransformPrimitive::SCALE2D: return Interpolate(variant.scale_2d, other_variant.scale_2d);
		case TransformPrimitive::SCALE3D: return Interpolate(variant.scale_3d, other_variant.scale_3d);
		case TransformPrimitive::ROTATEX: return Interpolate(variant.rotate_x, other_variant.rotate_x);
		case TransformPrimitive::ROTATEY: return Interpolate(variant.rotate_y, other_variant.rotate_y);
		case TransformPrimitive::ROTATEZ: return Interpolate(variant.rotate_z, other_variant.rotate_z);
		case TransformPrimitive::ROTATE2D: return Interpolate(variant.rotate_2d, other_variant.rotate_2d);
		case TransformPrimitive::ROTATE3D: return Interpolate(variant.rotate_3d, other_variant.rotate_3d);
		case TransformPrimitive::SKEWX: return Interpolate(variant.skew_x, other_variant.skew_x);
		case TransformPrimitive::SKEWY: return Interpolate(variant.skew_y, other_variant.skew_y);
		case TransformPrimitive::SKEW2D: return Interpolate(variant.skew_2d, other_variant.skew_2d);
		case TransformPrimitive::PERSPECTIVE: return Interpolate(variant.perspective, other_variant.perspective);
		case TransformPrimitive::DECOMPOSEDMATRIX4: return Interpolate(variant.decomposed_matrix_4, other_variant.decomposed_matrix_4);
		}
		RMLUI_ASSERT(false);
		return false;
	}
};

bool TransformUtilities::InterpolateWith(TransformPrimitive& target, const TransformPrimitive& other, float alpha) noexcept
{
	if (target.type != other.type)
		return false;

	bool result = InterpolateVisitor{ other, alpha }.run(target);
	return result;
}


template<size_t N>
static inline String ToString(const Transforms::ResolvedPrimitive<N>& p, String unit, bool rad_to_deg = false, bool only_unit_on_last_value = false) noexcept {
	float multiplier = 1.0f;
	String tmp;
	String result = "(";
	for (size_t i = 0; i < N; i++)
	{
		if (only_unit_on_last_value && i < N - 1)
			multiplier = 1.0f;
		else if (rad_to_deg)
			multiplier = 180.f / Math::RMLUI_PI;

		if (TypeConverter<float, String>::Convert(p.values[i] * multiplier, tmp))
			result += tmp;

		if (!unit.empty() && (!only_unit_on_last_value || (i == N - 1)))
			result += unit;

		if (i < N - 1)
			result += ", ";
	}
	result += ")";
	return result;
}

template<size_t N>
static inline String ToString(const Transforms::UnresolvedPrimitive<N>& p) noexcept {
	String result = "(";
	for (size_t i = 0; i < N; i++)
	{
		result += ToString(p.values[i]);
		if (i != N - 1)
			result += ", ";
	}
	result += ")";
	return result;
}

static inline String ToString(const Transforms::DecomposedMatrix4& p) noexcept {
	static const Transforms::DecomposedMatrix4 d{
		glm::vec4(0, 0, 0, 1),
		glm::quat(0, 0, 0, 1),
		glm::vec3(0, 0, 0),
		glm::vec3(1, 1, 1),
		glm::vec3(0, 0, 0)
	};
	String tmp;
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

	if (result.size() > 2)
		result.resize(result.size() - 2);

	result = "decomposedMatrix3d{ " + result + " }";

	return result;
}

static inline String ToString(const Transforms::Matrix2D& p) noexcept { return "matrix" + ToString(static_cast<const Transforms::ResolvedPrimitive< 6 >&>(p), ""); }
static inline String ToString(const Transforms::Matrix3D& p) noexcept { return "matrix3d" + ToString(static_cast<const Transforms::ResolvedPrimitive< 16 >&>(p), ""); }
static inline String ToString(const Transforms::TranslateX& p) noexcept { return "translateX" + ToString(static_cast<const Transforms::UnresolvedPrimitive< 1 >&>(p)); }
static inline String ToString(const Transforms::TranslateY& p) noexcept { return "translateY" + ToString(static_cast<const Transforms::UnresolvedPrimitive< 1 >&>(p)); }
static inline String ToString(const Transforms::TranslateZ& p) noexcept { return "translateZ" + ToString(static_cast<const Transforms::UnresolvedPrimitive< 1 >&>(p)); }
static inline String ToString(const Transforms::Translate2D& p) noexcept { return "translate" + ToString(static_cast<const Transforms::UnresolvedPrimitive< 2 >&>(p)); }
static inline String ToString(const Transforms::Translate3D& p) noexcept { return "translate3d" + ToString(static_cast<const Transforms::UnresolvedPrimitive< 3 >&>(p)); }
static inline String ToString(const Transforms::ScaleX& p) noexcept { return "scaleX" + ToString(static_cast<const Transforms::ResolvedPrimitive< 1 >&>(p), ""); }
static inline String ToString(const Transforms::ScaleY& p) noexcept { return "scaleY" + ToString(static_cast<const Transforms::ResolvedPrimitive< 1 >&>(p), ""); }
static inline String ToString(const Transforms::ScaleZ& p) noexcept { return "scaleZ" + ToString(static_cast<const Transforms::ResolvedPrimitive< 1 >&>(p), ""); }
static inline String ToString(const Transforms::Scale2D& p) noexcept { return "scale" + ToString(static_cast<const Transforms::ResolvedPrimitive< 2 >&>(p), ""); }
static inline String ToString(const Transforms::Scale3D& p) noexcept { return "scale3d" + ToString(static_cast<const Transforms::ResolvedPrimitive< 3 >&>(p), ""); }
static inline String ToString(const Transforms::RotateX& p) noexcept { return "rotateX" + ToString(static_cast<const Transforms::ResolvedPrimitive< 1 >&>(p), "deg", true); }
static inline String ToString(const Transforms::RotateY& p) noexcept { return "rotateY" + ToString(static_cast<const Transforms::ResolvedPrimitive< 1 >&>(p), "deg", true); }
static inline String ToString(const Transforms::RotateZ& p) noexcept { return "rotateZ" + ToString(static_cast<const Transforms::ResolvedPrimitive< 1 >&>(p), "deg", true); }
static inline String ToString(const Transforms::Rotate2D& p) noexcept { return "rotate" + ToString(static_cast<const Transforms::ResolvedPrimitive< 1 >&>(p), "deg", true); }
static inline String ToString(const Transforms::Rotate3D& p) noexcept { return "rotate3d" + ToString(static_cast<const Transforms::ResolvedPrimitive< 4 >&>(p), "deg", true, true); }
static inline String ToString(const Transforms::SkewX& p) noexcept { return "skewX" + ToString(static_cast<const Transforms::ResolvedPrimitive< 1 >&>(p), "deg", true); }
static inline String ToString(const Transforms::SkewY& p) noexcept { return "skewY" + ToString(static_cast<const Transforms::ResolvedPrimitive< 1 >&>(p), "deg", true); }
static inline String ToString(const Transforms::Skew2D& p) noexcept { return "skew" + ToString(static_cast<const Transforms::ResolvedPrimitive< 2 >&>(p), "deg", true); }
static inline String ToString(const Transforms::Perspective& p) noexcept { return "perspective" + ToString(static_cast<const Transforms::UnresolvedPrimitive< 1 >&>(p)); }

struct ToStringVisitor
{
	String run(const TransformPrimitive& variant)
	{
		switch (variant.type)
		{
		case TransformPrimitive::MATRIX2D: return ToString(variant.matrix_2d);
		case TransformPrimitive::MATRIX3D: return ToString(variant.matrix_3d);
		case TransformPrimitive::TRANSLATEX: return ToString(variant.translate_x);
		case TransformPrimitive::TRANSLATEY: return ToString(variant.translate_y);
		case TransformPrimitive::TRANSLATEZ: return ToString(variant.translate_z);
		case TransformPrimitive::TRANSLATE2D: return ToString(variant.translate_2d);
		case TransformPrimitive::TRANSLATE3D: return ToString(variant.translate_3d);
		case TransformPrimitive::SCALEX: return ToString(variant.scale_x);
		case TransformPrimitive::SCALEY: return ToString(variant.scale_y);
		case TransformPrimitive::SCALEZ: return ToString(variant.scale_z);
		case TransformPrimitive::SCALE2D: return ToString(variant.scale_2d);
		case TransformPrimitive::SCALE3D: return ToString(variant.scale_3d);
		case TransformPrimitive::ROTATEX: return ToString(variant.rotate_x);
		case TransformPrimitive::ROTATEY: return ToString(variant.rotate_y);
		case TransformPrimitive::ROTATEZ: return ToString(variant.rotate_z);
		case TransformPrimitive::ROTATE2D: return ToString(variant.rotate_2d);
		case TransformPrimitive::ROTATE3D: return ToString(variant.rotate_3d);
		case TransformPrimitive::SKEWX: return ToString(variant.skew_x);
		case TransformPrimitive::SKEWY: return ToString(variant.skew_y);
		case TransformPrimitive::SKEW2D: return ToString(variant.skew_2d);
		case TransformPrimitive::PERSPECTIVE: return ToString(variant.perspective);
		case TransformPrimitive::DECOMPOSEDMATRIX4: return ToString(variant.decomposed_matrix_4);
		default:
			break;
		}
		RMLUI_ASSERT(false);
		return String();
	}
};

String TransformUtilities::ToString(const TransformPrimitive& p) noexcept
{
	String result = ToStringVisitor{}.run(p);
	return result;
}


bool TransformUtilities::Decompose(Transforms::DecomposedMatrix4& d, const glm::mat4x4& m) noexcept
{
	return glm::decompose(m, d.scale, d.quaternion, d.translation, d.skew, d.perspective);
}

} // namespace Rml
