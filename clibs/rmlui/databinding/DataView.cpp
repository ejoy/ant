#include "databinding/DataView.h"
#include "core/Element.h"

namespace Rml {

static int GetElementDepth(Element* e) {
	int depth = 0;
	for (Element* parent = e->GetParentNode(); parent; parent = parent->GetParentNode()) {
		depth++;
	}
	return depth;
}

DataView::DataView(Element* element)
	: depth(GetElementDepth(element))
{ }

int DataView::GetDepth() const {
	return depth;
}

}
