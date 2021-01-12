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

#include "../Include/RmlUi/Geometry.h"
#include "../Include/RmlUi/Context.h"
#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/RenderInterface.h"
#include <utility>


namespace Rml {

Geometry::Geometry()
{
}

Geometry::Geometry(Geometry&& other)
{
	MoveFrom(other);
}

Geometry& Geometry::operator=(Geometry&& other)
{
	MoveFrom(other);
	// Keep the database handles from construction unchanged, they are tied to the *this* pointer and should not change.
	return *this;
}

void Geometry::MoveFrom(Geometry& other)
{
	vertices = std::move(other.vertices);
	indices = std::move(other.indices);
	texture = std::exchange(other.texture, nullptr);
}

Geometry::~Geometry()
{
}

void Geometry::Render(Point translation) {
	if (vertices.empty() || indices.empty())
		return;
	GetRenderInterface()->RenderGeometry(
		&vertices[0],
		(int)vertices.size(),
		&indices[0],
		(int)indices.size(),
		texture ? texture->GetHandle() : 0,
		translation
	);
}

Vector< Vertex >& Geometry::GetVertices() {
	return vertices;
}

Vector< int >& Geometry::GetIndices() {
	return indices;
}

void Geometry::SetTexture(SharedPtr<Texture> _texture) {
	texture = _texture;
}

void Geometry::Release() {
	vertices.clear();
	indices.clear();
}

Geometry::operator bool() const {
	return !indices.empty();
}

} // namespace Rml
