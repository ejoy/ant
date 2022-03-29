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

#ifndef RMLUI_CORE_RENDERINTERFACE_H
#define RMLUI_CORE_RENDERINTERFACE_H

#include "Texture.h"
#include "Geometry.h"
#include "Types.h"
#include <glm/glm.hpp>

namespace Rml {

class RenderInterface {
public:
	virtual void RenderGeometry(Vertex* vertices, size_t num_vertices, Index* indices, size_t num_indices, TextureHandle texture, SamplerFlag flags) = 0;
	virtual bool LoadTexture(TextureHandle& handle, Size& dimensions, const std::string& path) = 0;
	virtual void ReleaseTexture(TextureHandle texture) = 0;
	virtual void SetTransform(const glm::mat4x4& transform) = 0;
	virtual void SetClipRect() = 0;
	virtual void SetClipRect(const glm::u16vec4& r) = 0;
	virtual void SetClipRect(glm::vec4 r[2]) = 0;
};

}
#endif
