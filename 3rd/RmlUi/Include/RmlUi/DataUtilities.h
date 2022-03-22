#pragma once

#include <string>
#include <vector>

namespace Rml {

class Element;
struct HtmlElement;

class DataUtilities {
public:
	static bool Initialise();
	static void Shutdown();
	static void ApplyDataViewsControllers(Element* element);
	static void ApplyDataViewFor(Element* element, const HtmlElement& inner_html);
};

}
