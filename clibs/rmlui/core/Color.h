#pragma once

#include <glm/glm.hpp>
#include <glm/gtc/color_space.hpp>
#include <string>

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

	static Color FromSRGB(glm::u8 r, glm::u8 g, glm::u8 b, glm::u8 a);
	std::string ToString() const;
	Color Interpolate(const Color& c1, float alpha) const;
	void ApplyOpacity(float opacity);
};

}
