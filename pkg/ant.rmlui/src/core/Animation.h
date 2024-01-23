#pragma once

#include <core/Tween.h>
#include <core/ID.h>
#include <css/PropertyIdSet.h>
#include <map>
#include <string>
#include <vector>

namespace Rml {

struct Transition {
	enum class Type: uint8_t { None, Id };
	float duration = 0.0f;
	float delay = 0.0f;
	Tween tween;
	Type type;
	PropertyIdSet ids;
};

struct Animation {
	float duration = 0.0f;
	float delay = 0.0f;
	Tween tween;
	int num_iterations = 1;
	bool alternate = false;
	std::string name;
};

}
