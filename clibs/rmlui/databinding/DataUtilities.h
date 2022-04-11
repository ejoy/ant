#pragma once

namespace Rml {

class Element;
class Text;

class DataUtilities {
public:
	static void ApplyDataViewsControllers(Element* element);
	static void ApplyDataViewFor(Element* element);
	static void ApplyDataViewText(Text* element);
};

}
