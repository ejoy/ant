#pragma once

#include <stdint.h>

namespace Rml { namespace Style {

enum class FontStyle : uint8_t { Normal, Italic };
enum class FontWeight : uint8_t { Normal, Bold };
enum class TextAlign : uint8_t { Left, Right, Center, Justify };
enum class TextDecorationLine : uint8_t { None, Underline, Overline, LineThrough };
enum class WordBreak : uint8_t { Normal, BreakAll, BreakWord };
enum class BoxType : uint8_t { PaddingBox, BorderBox, ContentBox };
enum class BackgroundSize : uint8_t { Unset, Auto, Cover, Contain };
enum class BackgroundLattice : uint8_t { Auto, Cover, Contain };
enum class PointerEvents : uint8_t { None, Auto };
enum class Filter : uint8_t { None, Gray };
enum class OriginX : uint8_t { Left, Center, Right };
enum class OriginY : uint8_t { Top, Center, Bottom };

}}
