#include "../Include/RmlUi/Node.h"
#include "../Include/RmlUi/Debug.h"
#include "../Include/RmlUi/Element.h"
#include <yoga/YGNode.h>

namespace Rml {

Node::~Node()
{}

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

Element* Node::GetParentNode() const {
	return parent;
}

void Node::DirtyLayout() {
	layout.MarkDirty();
}

}
