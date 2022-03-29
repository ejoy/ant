#include "core/Node.h"
#include "core/Element.h"
#include <yoga/YGNode.h>

namespace Rml {

Node::~Node()
{}

bool Node::UpdateVisible() {
	return layout.UpdateVisible(metrics);
}

void Node::UpdateMetrics(const Rect& child) {
	layout.UpdateMetrics(metrics, child);
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
// fixed nested data-if for same variant bug
// 	if (IsVisible() == visible) {
// 		return;
// 	}
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

DataModel* Node::GetDataModel() const {
	return data_model;
}

}
