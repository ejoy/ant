#include "../Include/RmlUi/Node.h"
#include "../Include/RmlUi/Debug.h"
#include "../Include/RmlUi/Element.h"
#include <yoga/YGNode.h>

namespace Rml {

void Node::SetType(Type type_) {
	type = type_;
}

Node::Type Node::GetType() {
	return type;
}

bool Node::UpdateMetrics() {
	return layout.UpdateMetrics(metrics);
}

Layout& Node::GetLayout() {
	return layout;
}

const Layout::Metrics& Node::GetMetrics() const {
	return metrics;
}

bool Node::IsVisible() const {
	return metrics.visible;
}

void Node::SetVisible(bool visible) {
	if (IsVisible() == visible) {
		return;
	}
	layout.SetVisible(visible);
}

void Node::SetParentNode(Element* parent_) {
	parent = parent_;
}

bool Node::DirtyOffset() {
	if (dirty_offset) {
		return false;
	}
	dirty_offset = true;
	return true;
}

const Point& Node::GetOffset() {
	if (dirty_offset) {
		dirty_offset = false;
		if (parent) {
			offset = metrics.frame.origin + parent->GetOffset();
		}
		else {
			offset = metrics.frame.origin;
		}
	}
	return offset;
}

}
