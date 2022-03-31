#include <core/Color.h>

namespace Rml {

Color Color::FromSRGB(glm::u8 r, glm::u8 g, glm::u8 b, glm::u8 a) {
	return glm::u8vec4(glm::convertSRGBToLinear(glm::vec4(r, g, b, a) / 255.f) * 255.f);
}

std::string Color::ToString() const {
	auto sRGB =  glm::convertLinearToSRGB(glm::vec4(r, g, b, a) / 255.f) * 255.f;
	return "rgba("
		+std::to_string(sRGB.r)+","
		+std::to_string(sRGB.g)+","
		+std::to_string(sRGB.b)+","
		+std::to_string(sRGB.a)+")";
}

Color Color::Interpolate(const Color& c1, float alpha) const {
	auto const& c0 = *this;
	return Color(
		glm::u8((1.0f - alpha) * c0.r + alpha * c1.r),
		glm::u8((1.0f - alpha) * c0.g + alpha * c1.g),
		glm::u8((1.0f - alpha) * c0.b + alpha * c1.b),
		glm::u8((1.0f - alpha) * c0.a + alpha * c1.a)
	);
}

void Color::ApplyOpacity(float opacity) {
	a = glm::u8((float)a * opacity);
}

}
