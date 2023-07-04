#include <core/Color.h>
#include <glm/glm.hpp>
#include <glm/gtc/color_space.hpp>

namespace Rml {

Color::Color()
{}

Color::Color(uint8_t r, uint8_t g, uint8_t b, uint8_t a)
	: r(r)
	, g(g)
	, b(b)
	, a(a)
{}

Color Color::FromSRGB(uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
	auto linear = glm::convertSRGBToLinear(glm::vec4(r, g, b, a) / 255.f) * 255.f;
	return {
		uint8_t(linear.r),
		uint8_t(linear.g),
		uint8_t(linear.b),
		uint8_t(linear.a),
	};
}

std::string Color::ToString() const {
	auto sRGB = glm::convertLinearToSRGB(glm::vec4(r, g, b, a) / 255.f) * 255.f;
	return "rgba("
		+std::to_string(sRGB.r)+","
		+std::to_string(sRGB.g)+","
		+std::to_string(sRGB.b)+","
		+std::to_string(sRGB.a)+")";
}

Color Color::Interpolate(const Color& c1, float alpha) const {
	auto const& c0 = *this;
	return {
		uint8_t((1.0f - alpha) * c0.r + alpha * c1.r),
		uint8_t((1.0f - alpha) * c0.g + alpha * c1.g),
		uint8_t((1.0f - alpha) * c0.b + alpha * c1.b),
		uint8_t((1.0f - alpha) * c0.a + alpha * c1.a),
	};
}

void Color::ApplyOpacity(float opacity) {
	a = uint8_t((float)a * opacity);
}

void Color::SetGray() {
	float gray[] = { 0.2126f, 0.7152f, 0.0722f};
	float s = gray[0] * r + gray[1] * g + gray[2] * b;
	r = g = b = (uint8_t)s;
}

bool Color::IsVisible() const {
	return a != 0;
}

bool Color::operator==(const Color& o) const {
	return (r == o.r)
		&& (g == o.g)
		&& (b == o.b)
		&& (a == o.a)
		;
}

}
