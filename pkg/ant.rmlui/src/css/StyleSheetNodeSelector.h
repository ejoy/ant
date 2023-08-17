#pragma once

#include <string>

namespace Rml {
	class Element;
	using IsApplicable = bool (*)(const Element* element, int a, int b);
	IsApplicable CreateSelector(std::string_view name);
}
