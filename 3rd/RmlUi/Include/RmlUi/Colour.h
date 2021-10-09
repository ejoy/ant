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

#ifndef RMLUI_CORE_COLOUR_H
#define RMLUI_CORE_COLOUR_H

#include "Platform.h"
#include <glm/glm.hpp>
#include <glm/gtc/color_space.hpp>

namespace Rml {
	
class Color : public glm::u8vec4 {
public:
	Color()
		: glm::u8vec4(0,0,0,255)
	{ }
	Color(glm::u8 r, glm::u8 g, glm::u8 b, glm::u8 a)
		: glm::u8vec4(r, g, b, a)
	{ }
	Color(glm::u8vec4&& v)
		: glm::u8vec4(std::forward<glm::u8vec4>(v))
	{ }
};

inline Color ColorInterpolate(const Color& c0, const Color& c1, float alpha) {
	return glm::mix(c0, c1, alpha);
}

inline void ColorApplyOpacity(Color& c, float opacity) {
	c.a = glm::u8((float)c.a * opacity);
}

} // namespace Rml




#endif
