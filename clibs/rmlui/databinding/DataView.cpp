#include "databinding/DataView.h"
#include "core/Element.h"

namespace Rml {

static int GetNodeDepth(Node* e) {
	int depth = 0;
	for (Element* parent = e->GetParentNode(); parent; parent = parent->GetParentNode()) {
		depth++;
	}
	return depth;
}

DataView::DataView(Node* node)
	: depth(GetNodeDepth(node))
{ }

int DataView::GetDepth() const {
	return depth;
}

}
