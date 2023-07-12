#pragma once

#include <string>
#include <stdint.h>

namespace Rml {

class Color {
public:
	Color();
	static Color FromSRGB(uint8_t r, uint8_t g, uint8_t b, uint8_t a);
	std::string ToString() const;
	Color Interpolate(const Color& c1, float alpha) const;
	void ApplyOpacity(float opacity);
	void SetGray();
	bool IsVisible() const;
	bool operator==(const Color& r) const;

	uint8_t r = 0;
	uint8_t g = 0;
	uint8_t b = 0;
	uint8_t a = 255;

private:
	Color(uint8_t r, uint8_t g, uint8_t b, uint8_t a);
};

}
