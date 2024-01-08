#pragma once

#include <string>
#include <stdint.h>

namespace Rml {

class Tween {
public:
	enum class Type : uint8_t { Linear = 0, Back, Bounce, Circular, Cubic, Elastic, Exponential, Quadratic, Quartic, Quintic, Sine };
	enum class Direction : uint8_t { In = 0, Out, InOut };

	Tween();
	Tween(Type type, Direction direction);
	float get(float t) const;
	std::string ToString() const;

private:
	uint8_t v;
};

}
