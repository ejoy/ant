#pragma once

#include <core/Color.h>
#include <core/Animation.h>
#include <core/Transform.h>
#include <css/PropertyFloat.h>
#include <css/PropertyKeyword.h>
#include <variant>
#include <string>

namespace Rml {

using Property = std::variant<
	PropertyFloat,
	PropertyKeyword,
	Color,
	std::string,
	Transform,
	TransitionList,
	AnimationList
>;

}
