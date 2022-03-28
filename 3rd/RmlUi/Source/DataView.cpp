#include "DataView.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/Log.h"
#include <algorithm>

namespace Rml {

Element* DataView::GetElement() const {
	Element* result = attached_element.get();
	if (!result)
		Log::Message(Log::Level::Warning, "Could not retrieve element in view, was it destroyed?");
	return result;
}

int DataView::GetElementDepth() const {
	return element_depth;
}

bool DataView::IsValid() const {
	return static_cast<bool>(attached_element);
}

DataView::DataView(Element* element)
	: attached_element(element->GetObserverPtr())
	, element_depth(0)
{
	if (element) {
		for (Element* parent = element->GetParentNode(); parent; parent = parent->GetParentNode())
			element_depth += 1;
	}
}

}
