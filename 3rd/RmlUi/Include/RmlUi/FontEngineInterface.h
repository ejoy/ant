/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2008-2010 CodePoint Ltd, Shift Technology Ltd
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

#ifndef RMLUI_CORE_FONTENGINEINTERFACE_H
#define RMLUI_CORE_FONTENGINEINTERFACE_H

#include "Header.h"
#include "Types.h"
#include "ComputedValues.h"
#include "Geometry.h"
#include "TextEffect.h"

namespace Rml {

/**
	The abstract base class for an application-specific font engine implementation.
	
	By default, RmlUi will use its own font engine with characters rendered through FreeType. To use your own engine,
	provide a concrete implementation of this class and install it through Rml::SetFontEngineInterface().
 */

struct Line {
	Line(const std::string& text, const Point& position) : text(text), position(position), width(0) {}
	std::string text;
	Point position;
	int width;
};
typedef std::vector<Line> LineList;

class RMLUICORE_API FontEngineInterface
{
public:
	FontEngineInterface();
	virtual ~FontEngineInterface();

	/// Called by RmlUi when a font configuration is resolved for an element. Should return a handle that 
	/// can later be used to resolve properties of the face, and generate string geometry to be rendered.
	/// @param[in] family The family of the desired font handle.
	/// @param[in] style The style of the desired font handle.
	/// @param[in] weight The weight of the desired font handle.
	/// @param[in] size The size of desired handle, in points.
	/// @return A valid handle if a matching (or closely matching) font face was found, NULL otherwise.
	virtual FontFaceHandle GetFontFaceHandle(const std::string& family, Style::FontStyle style, Style::FontWeight weight, int size);

	/// Called by RmlUi when a list of font effects is resolved for an element with a given font face.
	/// @param[in] handle The font handle.
	/// @param[in] effects The list of text effects to generate the configuration for.
	/// @return A handle to the prepared font effects which will be used when generating geometry for a string.
	virtual TextEffectsHandle PrepareTextEffects(FontFaceHandle handle, const TextEffects &effects);

	/// Should return the point size of this font face.
	/// @param[in] handle The font handle.
	/// @return The face's point size.
	virtual int GetSize(FontFaceHandle handle);
	/// Should return the pixel height of a lower-case x in this font face.
	/// @param[in] handle The font handle.
	/// @return The height of a lower-case x.
	virtual int GetXHeight(FontFaceHandle handle);
	/// Should return the default height between this font face's baselines.
	/// @param[in] handle The font handle.
	/// @return The default line height.
	virtual int GetLineHeight(FontFaceHandle handle);

	/// Should return the font's baseline, as a pixel offset from the bottom of the font.
	/// @param[in] handle The font handle.
	/// @return The font's baseline.
	virtual int GetBaseline(FontFaceHandle handle);

	/// Should return the font's underline, as a pixel offset from the bottom of the font.
	/// @param[in] handle The font handle.
	/// @param[out] The underline pixel offset.
	/// @param[out] thickness The font's underline thickness in pixels.
	virtual void GetUnderline(FontFaceHandle handle, float& position, float &thickness);

	/// Called by RmlUi when it wants to retrieve the width of a string when rendered with this handle.
	/// @param[in] handle The font handle.
	/// @param[in] string The string to measure.
	/// @param[in] prior_character The optionally-specified character that immediately precedes the string. This may have an impact on the string width due to kerning.
	/// @return The width, in pixels, this string will occupy if rendered with this handle.
	virtual int GetStringWidth(FontFaceHandle handle, const std::string& string, Character prior_character = Character::Null);

	/// Called by RmlUi when it wants to retrieve the geometry required to render a single line of text.
	/// @param[in] face_handle The font handle.
	/// @param[in] text_effects_handle The handle to the prepared font effects for which the geometry should be generated.
	/// @param[in] lines The string to render.
	/// @param[in] colour The colour to render the text.
	/// @param[out] geometry An array of geometries to generate the geometry into.
	/// @return The width, in pixels, of the string geometry.
	virtual void GenerateString(FontFaceHandle face_handle, TextEffectsHandle text_effects_handle, LineList& lines, const Color& colour, GeometryList& geometry);
};

} // namespace Rml
#endif
