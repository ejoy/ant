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
#include <optional>

namespace Rml {

class RMLUICORE_API ElementText final : public Element {
public:
	ElementText(Document* owner, const std::string& text);
	virtual ~ElementText();

	void SetText(const std::string& text);
	const std::string& GetText() const;

	Size Measure(float minWidth, float maxWidth, float minHeight, float maxHeight);
	float GetBaseline();

protected:
	void OnRender() override;
	void OnChange(const PropertyIdSet& properties) override;

	const Property* GetProperty(PropertyId id);
	float GetOpacity();

private:
	void UpdateTextEffects();
	void UpdateGeometry(const FontFaceHandle font_face_handle);
	void UpdateDecoration(const FontFaceHandle font_face_handle);

	bool GenerateLine(std::string& line, int& line_length, float& line_width, int line_begin, float maximum_line_width, bool trim_whitespace_prefix);
	void ClearLines();
	void AddLine(const Point& line_position, const std::string& line);

	float GetLineHeight();
	Style::TextAlign GetAlign();
	std::optional<TextShadow> GetTextShadow();
	std::optional<TextStroke> GetTextStroke();
	Style::TextDecorationLine GetTextDecorationLine();
	Color GetTextDecorationColor();
	Style::TextTransform GetTextTransform();
	Style::WhiteSpace GetWhiteSpace();
	Style::WordBreak GetWordBreak();
	Color GetTextColor();
	FontFaceHandle GetFontFaceHandle();

	bool dirty_geometry = true;
	bool dirty_decoration = true;
	bool dirty_effects = false;
	bool dirty_font = false;

	std::string text;
	LineList lines;
	Geometry geometry;
	Geometry decoration;
	bool decoration_under = true;
	TextEffectsHandle text_effects_handle = 0;
	FontFaceHandle font_handle = 0;
};

} // namespace Rml
#endif
