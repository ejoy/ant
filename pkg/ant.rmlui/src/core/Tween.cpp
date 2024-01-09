#include <core/Tween.h>
#include <utility>
#include <math.h>
#include <bee/nonstd/unreachable.h>

#include <version>
#if defined(__cpp_lib_math_constants)
#	include <numbers>
static constexpr float const_pi = std::numbers::pi_v<float>;
#else
static constexpr float const_pi = static_cast<float>(3.141592653589793);
#endif

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
	return -expf(7.24f * (t - 1.f)) * sinf((t - 1.1f) * 2.f * const_pi / 0.4f);
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
	return 1.f - cosf(t * const_pi * 0.5f);
}

}

static float TweenIn(Tween::Type type, float t) {
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
		std::unreachable();
	}
}

static float TweenOut(Tween::Type type, float t) {
	return 1.0f - TweenIn(type, 1.0f - t);
}

static float TweenInOut(Tween::Type type, float t) {
	if (t < 0.5f)
		return TweenIn(type, 2.0f * t) * 0.5f;
	else
		return 0.5f + TweenOut(type, 2.0f * t - 1.0f) * 0.5f;
}

static std::string TweenToString(Tween::Type type) {
	switch (type) {
	case Tween::Type::Back:
		return "back";
	case Tween::Type::Bounce:
		return "bounce";
	case Tween::Type::Circular:
		return "circular";
	case Tween::Type::Cubic:
		return "cubic";
	case Tween::Type::Elastic:
		return "elastic";
	case Tween::Type::Exponential:
		return "exponential";
	case Tween::Type::Linear:
		return "linear";
	case Tween::Type::Quadratic:
		return "quadratic";
	case Tween::Type::Quartic:
		return "quartic";
	case Tween::Type::Quintic:
		return "quintic";
	case Tween::Type::Sine:
		return "sine";
	default:
		std::unreachable();
	}
}

static std::string TweenToString(Tween::Direction direction) {
	switch (direction) {
	case Tween::Direction::In:
		return "-in";
	case Tween::Direction::Out:
		return "-out";
	case Tween::Direction::InOut:
		return "-in-out";
	default:
		std::unreachable();
	}
}

static Tween::Type TweenGetType(uint8_t v) {
	return (Tween::Type)((v >> 4) & 0xF);
}

static Tween::Direction TweenGetDirection(uint8_t v) {
	return (Tween::Direction)(v & 0xF);
}

static uint8_t TweenMake(Tween::Type type, Tween::Direction direction) {
	return (uint8_t(type) << 4) | uint8_t(direction);
}

Tween::Tween()
	: v(0)
{ }

Tween::Tween(Type type, Direction direction)
	: v(TweenMake(type, direction))
{ }

float Tween::get(float t) const {
	switch (TweenGetDirection(v)) {
	case Direction::In:
		return TweenIn(TweenGetType(v), t);
	case Direction::Out:
		return TweenOut(TweenGetType(v), t);
	case Direction::InOut:
		return TweenInOut(TweenGetType(v), t);
	default:
		std::unreachable();
	}
	return t;
}

std::string Tween::ToString() const {
	return TweenToString(TweenGetType(v)) + TweenToString(TweenGetDirection(v));
}

}
