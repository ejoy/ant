/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
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

#ifndef RMLUI_CORE_COMPUTEDVALUES_H
#define RMLUI_CORE_COMPUTEDVALUES_H

#include "Types.h"
#include "Animation.h"
#include "TextEffect.h"
#include <optional>

namespace Rml {

namespace Style
{

struct LengthPercentageAuto {
	enum Type { Auto, Length, Percentage } type = Length;
	float value = 0;
	LengthPercentageAuto() {}
	LengthPercentageAuto(Type type, float value = 0) : type(type), value(value) {}
};
struct LengthPercentage {
	enum Type { Length, Percentage } type = Length;
	float value = 0;
	LengthPercentage() {}
	LengthPercentage(Type type, float value = 0) : type(type), value(value) {}
};

struct NumberAuto {
	enum Type { Auto, Number } type = Number;
	float value = 0;
	NumberAuto() {}
	NumberAuto(Type type, float value = 0) : type(type), value(value) {}
};

struct Color {
	enum class Type { CurrentColor, Value };
	Type type = Type::Value;
	Colourb value = 0;
	Color(Colourb const& v)
		: type(Type::Value)
		, value(v)
	{ }
	Color(Type const& t)
		: type(t)
		, value()
	{ }
};

enum class Position : uint8_t { Static, Relative, Absolute };

using ZIndex = NumberAuto;

enum class FontStyle : uint8_t { Normal, Italic };
enum class FontWeight : uint8_t { Normal, Bold };
enum class TextAlign : uint8_t { Left, Right, Center, Justify };
enum class TextDecorationLine : uint8_t { None, Underline, Overline, LineThrough };
enum class TextTransform : uint8_t { None, Capitalize, Uppercase, Lowercase };
enum class WhiteSpace : uint8_t { Normal, Pre, Nowrap, Prewrap, Preline };
enum class WordBreak : uint8_t { Normal, BreakAll, BreakWord };
enum class Drag : uint8_t { None, Drag, DragDrop, Block, Clone };
enum class Focus : uint8_t { None, Auto };
enum class PointerEvents : uint8_t { None, Auto };

using PerspectiveOrigin = LengthPercentage;
using TransformOrigin = LengthPercentage;

enum class OriginX : uint8_t { Left, Center, Right };
enum class OriginY : uint8_t { Top, Center, Bottom };

/* 
	A computed value is a value resolved as far as possible :before: introducing layouting. See CSS specs for details of each property.

	Note: Enums and default values must correspond to the keywords and defaults in `StyleSheetSpecification.cpp`.
*/

struct ComputedValues
{
	Colourb border_top_color{ 255, 255, 255 }, border_right_color{ 255, 255, 255 }, border_bottom_color{ 255, 255, 255 }, border_left_color{ 255, 255, 255 };
	float border_top_left_radius = 0, border_top_right_radius = 0, border_bottom_right_radius = 0, border_bottom_left_radius = 0;

	ZIndex z_index = { ZIndex::Auto };

	Colourb color = Colourb(255, 255, 255);
	Colourb image_color = Colourb(255, 255, 255);
	float opacity = 1;

	String font_family;
	FontStyle font_style = FontStyle::Normal;
	FontWeight font_weight = FontWeight::Normal;
	float font_size = 12.f;
	// Font face used to render text and resolve ex properties. Does not represent a true property
	// like most computed values, but placed here as it is used and inherited in a similar manner.
	FontFaceHandle font_face_handle = 0;

	TextAlign text_align = TextAlign::Left;
	TextTransform text_transform = TextTransform::None;
	WhiteSpace white_space = WhiteSpace::Normal;
	WordBreak word_break = WordBreak::Normal;

	TextDecorationLine text_decoration_line = TextDecorationLine::None;
	Color text_decoration_color = Color(Color::Type::CurrentColor);

	Drag drag = Drag::None;
	Focus focus = Focus::Auto;
	PointerEvents pointer_events = PointerEvents::Auto;

	float perspective = 0;
	PerspectiveOrigin perspective_origin_x = { PerspectiveOrigin::Percentage, 50.f };
	PerspectiveOrigin perspective_origin_y = { PerspectiveOrigin::Percentage, 50.f };

	TransformPtr transform;
	TransformOrigin transform_origin_x = { TransformOrigin::Percentage, 50.f };
	TransformOrigin transform_origin_y = { TransformOrigin::Percentage, 50.f };
	float transform_origin_z = 0.0f;

	TransitionList transition;
	AnimationList animation;

	Colourb background_color = Colourb(255, 255, 255, 0);
	String background_image;
	
	std::optional<TextShadow> text_shadow;
	std::optional<TextStroke> text_stroke;
};
}

using ComputedValues = Style::ComputedValues;

} // namespace Rml
#endif
