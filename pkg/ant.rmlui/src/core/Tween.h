#pragma once

#include <string>
#include <stdint.h>

namespace Rml {

enum class Tween : uint8_t {
	LinearIn,
	LinearOut,
	LinearInOut,
	BackIn,
	BackOut,
	BackInOut,
	BounceIn,
	BounceOut,
	BounceInOut,
	CircularIn,
	CircularOut,
	CircularInOut,
	CubicIn,
	CubicOut,
	CubicInOut,
	ElasticIn,
	ElasticOut,
	ElasticInOut,
	ExponentialIn,
	ExponentialOut,
	ExponentialInOut,
	QuadraticIn,
	QuadraticOut,
	QuadraticInOut,
	QuarticIn,
	QuarticOut,
	QuarticInOut,
	QuinticIn,
	QuinticOut,
	QuinticInOut,
	SineIn,
	SineOut,
	SineInOut,
};

float TweenGet(Tween tween, float t);

}
