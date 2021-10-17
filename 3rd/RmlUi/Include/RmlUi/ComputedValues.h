#pragma once

#include "Types.h"
#include "Animation.h"
#include "TextEffect.h"
#include "Property.h"

namespace Rml { namespace Style {

enum class FontStyle : uint8_t { Normal, Italic };
enum class FontWeight : uint8_t { Normal, Bold };
enum class TextAlign : uint8_t { Left, Right, Center, Justify };
enum class TextDecorationLine : uint8_t { None, Underline, Overline, LineThrough };
enum class TextTransform : uint8_t { None, Capitalize, Uppercase, Lowercase };
enum class WhiteSpace : uint8_t { Normal, Pre, Nowrap, Prewrap, Preline };
enum class WordBreak : uint8_t { Normal, BreakAll, BreakWord };
enum class Drag : uint8_t { None, Drag, DragDrop, Block, Clone };
enum class BoxType : uint8_t { PaddingBox, BorderBox, ContentBox };
enum class BackgroundSize : uint8_t { Auto, Cover, Contain };

struct ComputedValues {
	TransitionList transition;
	AnimationList animation;
	EdgeInsets<Color> border_color;
	CornerInsets<FloatValue> border_radius{};
	Color background_color = Color(255, 255, 255, 0);
};

}}
