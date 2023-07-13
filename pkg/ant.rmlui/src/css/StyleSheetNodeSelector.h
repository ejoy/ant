#pragma once

namespace Rml {
	class Element;
}

namespace Rml::Selector {
	using IsApplicable = bool (*)(const Element* element, int a, int b);

	bool Empty(const Element* element, int a, int b);
	bool FirstChild(const Element* element, int a, int b);
	bool FirstOfType(const Element* element, int a, int b);
	bool LastChild(const Element* element, int a, int b);
	bool LastOfType(const Element* element, int a, int b);
	bool NthChild(const Element* element, int a, int b);
	bool NthLastChild(const Element* element, int a, int b);
	bool NthLastOfType(const Element* element, int a, int b);
	bool NthOfType(const Element* element, int a, int b);
	bool OnlyChild(const Element* element, int a, int b);
	bool OnlyOfType(const Element* element, int a, int b);
}
