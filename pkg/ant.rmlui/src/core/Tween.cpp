#include <core/Tween.h>
#include <utility>
#include <bee/nonstd/to_underlying.h>
#include <bee/nonstd/unreachable.h>
#include <numbers>
#include <cmath>

static constexpr auto const_pi = std::numbers::pi_v<float>;

namespace Rml {

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
	return 1.f - std::sqrt(1.f - t * t);
}

static float cubic(float t) {
	return t * t * t;
}

static float elastic(float t) {
	if (t == 0) return t;
	if (t == 1) return t;
	return -std::exp(7.24f * (t - 1.f)) * std::sin((t - 1.1f) * 2.f * const_pi / 0.4f);
}

static float exponential(float t) {
	if (t == 0) return t;
	if (t == 1) return t;
	return std::exp(7.24f * (t - 1.f));
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
	return 1.f - std::cos(t * const_pi * 0.5f);
}

enum class Direction : uint8_t {
	In = 0,
	Out,
	InOut
};

static float TweenIn(float t) {
	return t;
}

static float TweenOut(float t) {
	return 1.0f - TweenIn(1.0f - t);
}

static float TweenInOut(float t) {
	if (t < 0.5f)
		return TweenIn(2.0f * t) * 0.5f;
	else
		return 0.5f + TweenOut(2.0f * t - 1.0f) * 0.5f;
}

static float TweenGet(Direction dir, float t) {
	switch (dir) {
	case Direction::In:
		return TweenIn(t);
	case Direction::Out:
		return TweenOut(t);
	case Direction::InOut:
		return TweenInOut(t);
	default:
		std::unreachable();
	}
	return t;
}

float TweenGet(Tween tween, float t) {
	Direction dir = (Direction)(std::to_underlying(tween) % 3);
	switch (tween) {
	case Tween::LinearIn:
	case Tween::LinearOut:
	case Tween::LinearInOut:
		return TweenGet(dir, linear(t));
	case Tween::BackIn:
	case Tween::BackOut:
	case Tween::BackInOut:
		return TweenGet(dir, back(t));
	case Tween::BounceIn:
	case Tween::BounceOut:
	case Tween::BounceInOut:
		return TweenGet(dir, bounce(t));
	case Tween::CircularIn:
	case Tween::CircularOut:
	case Tween::CircularInOut:
		return TweenGet(dir, circular(t));
	case Tween::CubicIn:
	case Tween::CubicOut:
	case Tween::CubicInOut:
		return TweenGet(dir, cubic(t));
	case Tween::ElasticIn:
	case Tween::ElasticOut:
	case Tween::ElasticInOut:
		return TweenGet(dir, elastic(t));
	case Tween::ExponentialIn:
	case Tween::ExponentialOut:
	case Tween::ExponentialInOut:
		return TweenGet(dir, exponential(t));
	case Tween::QuadraticIn:
	case Tween::QuadraticOut:
	case Tween::QuadraticInOut:
		return TweenGet(dir, quadratic(t));
	case Tween::QuarticIn:
	case Tween::QuarticOut:
	case Tween::QuarticInOut:
		return TweenGet(dir, quartic(t));
	case Tween::QuinticIn:
	case Tween::QuinticOut:
	case Tween::QuinticInOut:
		return TweenGet(dir, quintic(t));
	case Tween::SineIn:
	case Tween::SineOut:
	case Tween::SineInOut:
		return TweenGet(dir, sine(t));
	default:
		std::unreachable();
	}
}

}
