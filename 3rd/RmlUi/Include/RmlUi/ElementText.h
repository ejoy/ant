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

#ifndef RMLUI_CORE_ELEMENTTEXT_H
#define RMLUI_CORE_ELEMENTTEXT_H

#include "Header.h"
#include "Element.h"
#include "Geometry.h"
#include "FontEngineInterface.h"

namespace Rml {

/**
	@author Peter Curry
 */

class RMLUICORE_API ElementText final : public Element
{
public:
	ElementText(const String& tag);
	virtual ~ElementText();

	/// Sets the raw string this text element contains. The actual rendered text may be different due to whitespace formatting.
	void SetText(const String& text);
	/// Returns the raw string this text element contains.
	const String& GetText() const;

	/// Generates a line of text rendered from this element.
	/// @param[out] line The characters making up the line, with white-space characters collapsed and endlines processed appropriately.
	/// @param[out] line_length The number of characters from the source string consumed making up this string; this may very well be different from line.size()!
	/// @param[out] line_width The width (in pixels) of the generated line.
	/// @param[in] line_begin The index of the first character to be rendered in the line.
	/// @param[in] maximum_line_width The width (in pixels) of space allowed for the line, or -1 for unlimited space.
	/// @param[in] trim_whitespace_prefix If we're collapsing whitespace, whether or not to remove all prefixing whitespace or collapse it down to a single space.
	/// @return True if the line reached the end of the element's text, false if not.
	bool GenerateLine(String& line, int& line_length, float& line_width, int line_begin, float maximum_line_width, bool trim_whitespace_prefix);

	/// Clears all lines of generated text and prepares the element for generating new lines.
	void ClearLines();
	/// Adds a new line into the text element.
	/// @param[in] line_position The position of this line, as an offset from the first line.
	/// @param[in] line The contents of the line.
	void AddLine(const Point& line_position, const String& line);

	Size Measure(float minWidth, float maxWidth, float minHeight, float maxHeight);
	float GetBaseline();

protected:
	void OnRender() override;

	void OnPropertyChange(const PropertyIdSet& properties) override;

	void GetRML(String& content) override;

private:
	bool UpdateTextEffects();

	// Clears and regenerates all of the text's geometry.
	void GenerateGeometry(const FontFaceHandle font_face_handle);
	// Generates any geometry necessary for rendering decoration (underline, strike-through, etc).
	void GenerateDecoration(const FontFaceHandle font_face_handle);

	float GetLineHeight();

	String text;

	LineList lines;

	GeometryList geometrys;
	bool geometry_dirty = true;

	Colourb colour = Colourb(255, 255, 255);

	// The decoration geometry we've generated for this string.
	Geometry decoration;
	bool decoration_dirty = true;
	bool decoration_under = true;

	TextEffectsHandle text_effects_handle = 0;
	bool text_effects_dirty = false;

	int font_handle_version = 0;
};

} // namespace Rml
#endif
