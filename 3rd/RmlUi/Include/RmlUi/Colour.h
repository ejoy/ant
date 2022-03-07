#pragma once

#include <glm/glm.hpp>
#include <glm/gtc/color_space.hpp>

namespace Rml {

class Color : public glm::u8vec4 {
public:
	constexpr Color()
		: glm::u8vec4(0,0,0,255)
	{ }
	constexpr Color(glm::u8 r, glm::u8 g, glm::u8 b, glm::u8 a)
		: glm::u8vec4(r, g, b, a)
	{ }
	constexpr Color(glm::u8vec4&& v)
		: glm::u8vec4(std::forward<glm::u8vec4>(v))
	{ }

	glm::u8vec4 toSRGB() const {
		return glm::convertLinearToSRGB(glm::vec4(r, g, b, a) / 255.f) * 255.f;
	}
};

inline Color ColorInterpolate(const Color& c0, const Color& c1, float alpha) {
	return Color(
		glm::u8((1.0f - alpha) * c0.r + alpha * c1.r),
		glm::u8((1.0f - alpha) * c0.g + alpha * c1.g),
		glm::u8((1.0f - alpha) * c0.b + alpha * c1.b),
		glm::u8((1.0f - alpha) * c0.a + alpha * c1.a)
	);
}

inline void ColorApplyOpacity(Color& c, float opacity) {
	c.a = glm::u8((float)c.a * opacity);
}

inline Color ColorFromSRGB(glm::u8 r, glm::u8 g, glm::u8 b, glm::u8 a) {
	return glm::u8vec4(glm::convertSRGBToLinear(glm::vec4(r, g, b, a) / 255.f) * 255.f);
}

}
