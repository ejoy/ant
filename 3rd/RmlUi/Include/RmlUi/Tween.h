#pragma once

#include "Types.h"

namespace Rml {

class Tween {
public:
	enum class Type { None, Back, Bounce, Circular, Cubic, Elastic, Exponential, Linear, Quadratic, Quartic, Quintic, Sine, Count };
	enum class Direction { In = 1, Out = 2, InOut = 3 };

	Tween();
	Tween(Type type, Direction direction);
	float operator()(float t) const;
	bool operator==(const Tween& other) const;
	bool operator!=(const Tween& other) const;
	std::string to_string() const;

private:
	float in(float t) const;
	float out(float t) const;
	float in_out(float t) const;

	Type type = Type::Linear;
	Direction direction = Direction::Out;
};

}
