#include "../Include/RmlUi/Tween.h"
#include <utility>
#include <numbers>

namespace Rml {

namespace TweenFunctions {

// Tweening functions below.
// Partly based on http://libclaw.sourceforge.net/tweeners.html

static float square(float t) {
	return t * t;
}

static float back(float t) {
	return t * t * (2.70158f * t - 1.70158f);
}

static float bounce(float t) {
	if (t > 1.f - 1.f / 2.75f)
		return 1.f - 7.5625f * square(1.f - t);
	else if (t > 1.f - 2.f / 2.75f)
		return 1.0f - (7.5625f * square(1.f - t - 1.5f / 2.75f) + 0.75f);
	else if (t > 1.f - 2.5f / 2.75f)
		return 1.0f - (7.5625f * square(1.f - t - 2.25f / 2.75f) + 0.9375f);
	return 1.0f - (7.5625f * square(1.f - t - 2.625f / 2.75f) + 0.984375f);
}

static float circular(float t) {
	return 1.f - sqrtf(1.f - t * t);
}

static float cubic(float t) {
	return t * t * t;
}

static float elastic(float t) {
	if (t == 0) return t;
	if (t == 1) return t;
	return -expf(7.24f * (t - 1.f)) * sinf((t - 1.1f) * 2.f * std::numbers::pi_v<float> / 0.4f);
}

static float exponential(float t) {
	if (t == 0) return t;
	if (t == 1) return t;
	return expf(7.24f * (t - 1.f));
}

static float linear(float t) {
	return t;
}

static float quadratic(float t) {
	return t * t;
}

static float quartic(float t) {
	return t * t * t * t;
}

static float quintic(float t) {
	return t * t * t * t * t;
}

static float sine(float t) {
	return 1.f - cosf(t * std::numbers::pi_v<float> * 0.5f);
}

}

static float tween(Tween::Type type, float t) {
	using namespace TweenFunctions;
	switch (type) {
	case Tween::Type::Back:
		return back(t);
	case Tween::Type::Bounce:
		return bounce(t);
	case Tween::Type::Circular:
		return circular(t);
	case Tween::Type::Cubic:
		return cubic(t);
	case Tween::Type::Elastic:
		return elastic(t);
	case Tween::Type::Exponential:
		return exponential(t);
	case Tween::Type::Linear:
		return linear(t);
	case Tween::Type::Quadratic:
		return quadratic(t);
	case Tween::Type::Quartic:
		return quartic(t);
	case Tween::Type::Quintic:
		return quintic(t);
	case Tween::Type::Sine:
		return sine(t);
	default:
		break;
	}
	return t;
}

Tween::Tween()
{ }

Tween::Tween(Type type, Direction direction)
: type(type)
, direction(direction)
{ }

float Tween::operator()(float t) const {
	switch (direction) {
	case Direction::In:
		return in(t);
	case Direction::Out:
		return out(t);
	case Direction::InOut:
		return in_out(t);
	}
	return t;
}

bool Tween::operator==(const Tween& other) const {
	return type == other.type && direction == other.direction;
} 


std::string Tween::ToString() const {
	static const std::array<std::string, size_t(Type::Count)> type_str = {
		{ "none", "back", "bounce", "circular", "cubic", "elastic", "exponential", "linear", "quadratic", "quartic", "quintic", "sine" }
	};

	if (size_t(type) < type_str.size()) {
		if (type == Type::None) {
			return "none";
		}
		switch (direction) {
		case Direction::In:
			return type_str[size_t(type)] + "-in";
		case Direction::Out:
			return type_str[size_t(type)] + "-out";
		case Direction::InOut:
			return type_str[size_t(type)] + "-in-out";
		}
	}
	return "unknown";
}

float Tween::in(float t) const {
	return tween(type, t);
}

float Tween::out(float t) const {
	return 1.0f - tween(type, 1.0f - t);
}

float Tween::in_out(float t) const {
	if (t < 0.5f)
		return tween(type, 2.0f * t) * 0.5f;
	else
		return 0.5f + out(2.0f * t - 1.0f) * 0.5f;
}

}
