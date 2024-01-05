#pragma once

#include <core/Color.h>
#include <core/Animation.h>
#include <core/Transform.h>
#include <css/PropertyFloat.h>
#include <variant>
#include <string>

namespace Rml {

using PropertyKeyword = int;
using AnimationList = std::vector<Animation>;

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
