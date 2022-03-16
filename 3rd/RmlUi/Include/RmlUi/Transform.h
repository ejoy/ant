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

#ifndef RMLUI_CORE_TRANSFORM_H
#define RMLUI_CORE_TRANSFORM_H

#include "Types.h"
#include "Property.h"
#include <variant>
#include <glm/glm.hpp>
#include <glm/gtx/quaternion.hpp>

namespace Rml {
namespace Transforms {

struct Matrix2D : glm::mat3x2 {
	Matrix2D() : glm::mat3x2(1) {}
	Matrix2D(glm::mat3x2&& o) : glm::mat3x2(std::forward<glm::mat3x2>(o)) {}
};

struct Matrix3D : glm::mat4x4 {
	Matrix3D() : glm::mat4x4(1) {}
	Matrix3D(glm::mat4x4&& o) : glm::mat4x4(std::forward<glm::mat4x4>(o)) {}
};

struct TranslateX {
	FloatValue x = { 0.f, Property::Unit::PX };
};

struct TranslateY {
	FloatValue y = { 0.f, Property::Unit::PX };
};

struct TranslateZ {
	FloatValue z = { 0.f, Property::Unit::PX };
};

struct Translate2D {
	FloatValue x = { 0.f, Property::Unit::PX };
	FloatValue y = { 0.f, Property::Unit::PX };
};

struct Translate3D {
	FloatValue x = { 0.f, Property::Unit::PX };
	FloatValue y = { 0.f, Property::Unit::PX };
	FloatValue z = { 0.f, Property::Unit::PX };
};

struct ScaleX {
	float x = 1.f;
};

struct ScaleY {
	float y = 1.f;
};

struct ScaleZ {
	float z = 1.f;
};

struct Scale2D {
	float x = 1.f;
	float y = 1.f;
};

struct Scale3D {
	float x = 1.f;
	float y = 1.f;
	float z = 1.f;
};

struct RotateX {
	FloatValue angle = { 0.f, Property::Unit::RAD };
};

struct RotateY {
	FloatValue angle = { 0.f, Property::Unit::RAD };
};

struct RotateZ {
	FloatValue angle = { 0.f, Property::Unit::RAD };
};

struct Rotate2D {
	FloatValue angle = { 0.f, Property::Unit::RAD };
};

struct Rotate3D {
	glm::vec3 axis = glm::vec3(0, 0, 1);
	FloatValue angle = { 0.f, Property::Unit::RAD };
};

struct SkewX {
	FloatValue x = { 0.f, Property::Unit::RAD };
};
struct SkewY {
	FloatValue y = { 0.f, Property::Unit::RAD };
};
struct Skew2D {
	FloatValue x = { 0.f, Property::Unit::RAD };
	FloatValue y = { 0.f, Property::Unit::RAD };
};
struct Perspective {
	FloatValue distance = { 0.f, Property::Unit::PX };
};

struct DecomposedMatrix4 {
	glm::vec4 perspective = glm::vec4(0, 0, 0, 1);
	glm::quat quaternion = glm::quat(0, 0, 0, 1);
	glm::vec3 translation = glm::vec3(0, 0, 0);
	glm::vec3 scale = glm::vec3(1, 1, 1);
	glm::vec3 skew = glm::vec3(0, 0, 0);
};

using Primitive = std::variant<
	Matrix2D,
	Matrix3D,
	TranslateX,
	TranslateY,
	TranslateZ,
	Translate2D,
	Translate3D,
	ScaleX,
	ScaleY,
	ScaleZ,
	Scale2D,
	Scale3D,
	RotateX,
	RotateY,
	RotateZ,
	Rotate2D,
	Rotate3D,
	SkewX,
	SkewY,
	Skew2D,
	Perspective,
	DecomposedMatrix4
>;

} // namespace Transforms

enum class TransformType {
	Scale, Translate, Rotate, Skew, Matrix
};

struct TransformPrimitive : public Transforms::Primitive {
	template <typename T>
	TransformPrimitive(T&& v)
		: Transforms::Primitive(std::forward<T>(v))
	{}
	void   SetIdentity();
	bool   PrepareForInterpolation(Element& e);
	void   ConvertToGenericType();
	bool   Interpolate(const TransformPrimitive& other, float alpha);
	TransformType GetType() const;
	std::string ToString() const;
};

class Transform : public std::vector<TransformPrimitive> {
public:
	std::unique_ptr<Transform> Interpolate(const Transform& other, float alpha);
	glm::mat4x4 GetMatrix(Element& e) const;
	bool Combine(Element& e, size_t start);
};

} // namespace Rml
#endif
