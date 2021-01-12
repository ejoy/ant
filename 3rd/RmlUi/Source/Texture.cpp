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

#include "../Include/RmlUi/Texture.h"
#include "../Include/RmlUi/RenderInterface.h"
#include "../Include/RmlUi/Core.h"

namespace Rml {

Texture::Texture(const String& _source)
	: source(_source) {
	if (!GetRenderInterface()->LoadTexture(handle, dimensions, source)) {
		Log::Message(Log::LT_WARNING, "Failed to load texture from %s.", source.c_str());
		handle = 0;
		dimensions = Size(0, 0);
	}
}

Texture::~Texture() {
	if (handle && GetRenderInterface()) {
		GetRenderInterface()->ReleaseTexture(handle);
		handle = 0;
	}
}

TextureHandle Texture::GetHandle() const {
	return handle;
}

const Size& Texture::GetDimensions() const {
	return dimensions;
}

using TextureMap = UnorderedMap<String, SharedPtr<Texture>>;
static TextureMap textures;

void Texture::Shutdown() {
#ifdef RMLUI_DEBUG
	// All textures not owned by the database should have been released at this point.
	int num_leaks_file = 0;
	for (auto& texture : textures) {
		num_leaks_file += (texture.second.use_count() > 1);
	}
	if (num_leaks_file > 0) {
		Log::Message(Log::LT_ERROR, "Textures leaked during shutdown. Total: %d.", num_leaks_file);
	}
#endif
	textures.clear();
}

SharedPtr<Texture> Texture::Fetch(const String& path) {
	auto iterator = textures.find(path);
	if (iterator != textures.end()) {
		return iterator->second;
	}
	auto resource = MakeShared<Texture>(path);
	textures[path] = resource;
	return resource;
}

} // namespace Rml
