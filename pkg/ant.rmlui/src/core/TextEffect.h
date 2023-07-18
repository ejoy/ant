#pragma once

#include <core/Color.h>
#include <optional>

namespace Rml {
	struct TextShadow {
		float offset_h = 0.0f;
		float offset_v = 0.0f;
		Color color = Color::FromSRGB(255, 255, 255, 0);
	};
	struct TextStroke {
		float width = 0.0f;
		Color color = Color::FromSRGB(255, 255, 255, 0);
	};
	struct TextEffect {
		std::optional<TextShadow> shadow;
		std::optional<TextStroke> stroke;
	};
}
