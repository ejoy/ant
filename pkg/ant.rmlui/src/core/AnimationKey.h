#pragma once

#include <css/Property.h>

namespace Rml {

struct AnimationKey {
	AnimationKey(float time, const Property& prop)
		: time(time)
		, prop(prop)
	{}
	float time;
	Property prop;
};

}
