#pragma once

#include "core/Colour.h"
#include <variant>
#include <vector>

namespace Rml {
	struct TextShadow {
		float offset_h = 0.0f;
		float offset_v = 0.0f;
		Color color = ColorFromSRGB(255, 255, 255, 0);
	};
	struct TextStroke {
		float width = 0.0f;
		Color color = ColorFromSRGB(255, 255, 255, 0);
	};
	using TextEffect = std::variant<TextShadow, TextStroke>;
	using TextEffects = std::vector<TextEffect>;
}
