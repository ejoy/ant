#pragma once

namespace Rml {

class Element;
class ElementText;

class DataUtilities {
public:
	static void ApplyDataViewsControllers(Element* element);
	static void ApplyDataViewFor(Element* element);
	static void ApplyDataViewText(ElementText* element);
};

}
