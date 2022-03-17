#pragma once

#include <string>
#include <vector>

namespace Rml {

class Element;

class DataUtilities {
public:
	static bool Initialise();
	static void Shutdown();
	static const std::vector<std::string>& GetStructuralDataViewAttributeNames();
	static bool ApplyDataViewsControllers(Element* element);
	static bool ApplyStructuralDataViews(Element* element, const std::string& inner_html);
};

}
