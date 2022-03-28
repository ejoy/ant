#include "DataView.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/Log.h"
#include <algorithm>

namespace Rml {

static int GetElementDepth(Element* e) {
	int depth = 0;
	for (Element* parent = e->GetParentNode(); parent; parent = parent->GetParentNode()) {
		depth++;
	}
	return depth;
}

Element* DataView::GetElement() const {
	Element* result = element.get();
	if (!result)
		Log::Message(Log::Level::Warning, "Could not retrieve element in view, was it destroyed?");
	return result;
}

int DataView::GetDepth() const {
	return depth;
}

bool DataView::IsValid() const {
	return static_cast<bool>(element);
}

DataView::DataView(Element* element)
	: element(element->GetObserverPtr())
	, depth(GetElementDepth(element))
{ }

}
