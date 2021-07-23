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

 
#ifndef RMLUI_CORE_ID_H
#define RMLUI_CORE_ID_H

#include <stdint.h>

namespace Rml {

enum class ShorthandId : uint8_t
{
	Invalid,

	/*
	  The following values define the shorthand ids for the main stylesheet specification.
	  These values must not be used in places that have their own property specification,
	  such as font-effects.
	*/
	Margin,
	Padding,
	BorderWidth,
	BorderColor,
	BorderTop,
	BorderRight,
	BorderBottom,
	BorderLeft,
	Border,
	BorderRadius,
	Font,
	PerspectiveOrigin,
	TransformOrigin,

	BackgroundPosition,
	Background, 
	TextShadow,
	TextStroke,
	TextDecoration,

	NumDefinedIds,
};


enum class PropertyId : uint8_t
{
	Invalid,

	/*
	  The following values define the property ids for the main stylesheet specification.
	  These values must not be used in places that have their own property specification,
	  such as font-effects.
	*/
	MarginTop,
	MarginRight,
	MarginBottom,
	MarginLeft,
	PaddingTop,
	PaddingRight,
	PaddingBottom,
	PaddingLeft,
	BorderTopWidth,
	BorderRightWidth,
	BorderBottomWidth,
	BorderLeftWidth,
	Display,
	Position,
	Overflow,
	Top,
	Right,
	Bottom,
	Left,
	AlignContent,
	AlignItems,
	AlignSelf,
	Direction,
	FlexDirection,
	FlexWrap,
	JustifyContent,
	AspectRatio,
	Flex,
	FlexBasis,
	FlexGrow,
	FlexShrink,

	BorderTopColor,
	BorderRightColor,
	BorderBottomColor,
	BorderLeftColor,
	BorderTopLeftRadius,
	BorderTopRightRadius,
	BorderBottomRightRadius,
	BorderBottomLeftRadius,
	ZIndex,
	Width,
	MinWidth,
	MaxWidth,
	Height,
	MinHeight,
	MaxHeight,
	LineHeight,
	Color,
	FontFamily,
	FontStyle,
	FontWeight,
	FontSize,
	TextAlign,
	TextDecorationLine,
	TextDecorationColor,
	TextTransform,
	WhiteSpace,
	WordBreak,
	Drag,

	Perspective,
	PerspectiveOriginX,
	PerspectiveOriginY,
	Transform,
	TransformOriginX,
	TransformOriginY,
	TransformOriginZ,

	Transition,
	Animation,

	Opacity,

	TextShadowH,
	TextShadowV,
	TextShadowColor,
	TextStrokeWidth,
	TextStrokeColor,

	BackgroundColor,
	BackgroundImage,
	BackgroundOrigin,
	BackgroundSize,
	BackgroundSizeX,
	BackgroundSizeY,
	BackgroundPositionX,
	BackgroundPositionY,
	BackgroundRepeat,

	NumDefinedIds,
};


enum class EventId : uint16_t 
{
	Invalid,

	// Core events
	Mousedown,
	Mousescroll,
	Mouseover,
	Mouseout,
	Focus,
	Blur,
	Keydown,
	Keyup,
	Textinput,
	Mouseup,
	Click,
	Dblclick,
	Load,
	Unload,
	Show,
	Hide,
	Mousemove,
	Dragmove,
	Drag,
	Dragstart,
	Dragover,
	Dragdrop,
	Dragout,
	Dragend,
	Handledrag,
	Resize,
	Scroll,
	Animationend,
	Transitionend,

	// Form control events
	Change,
	Submit,
	Tabchange,
	Columnadd,
	Rowadd,
	Rowchange,
	Rowremove,
	Rowupdate,

	NumDefinedIds,

	// Custom IDs start here
	FirstCustomId = NumDefinedIds,
};

enum class MouseButton {
	None = -1,
	Left = 0,
	Right = 1,
	Middle = 2,
};

} // namespace Rml
#endif
