#include <core/Node.h>
#include <core/Element.h>

namespace Rml {

Node::Node(Layout::UseElement use)
	: layout(use)
{}

Node::Node(Layout::UseText use, void* context)
	: layout(use, context)
{}

Node::~Node()
{}

void Node::ResetParentNode() {
	parent = nullptr;
}

Layout& Node::GetLayout() {
	return layout;
}

const Layout& Node::GetLayout() const {
	return layout;
}

bool Node::IsVisible() const {
	return visible;
}

void Node::SetVisible(bool visible) {
	layout.SetVisible(visible);
}

Element* Node::GetParentNode() const {
	return parent;
}

void Node::DirtyLayout() {
	layout.MarkDirty();
}

Layout::Type Node::GetType() const {
	return layout.GetType();
}

void Node::UpdateLayout() {
	if (layout.HasNewLayout()) {
		visible = layout.IsVisible();
		if (visible) {
			bounds = layout.GetBounds();
			CalculateLayout();
		}
	}
}

const Rect& Node::GetBounds() const {
	return bounds;
}

}
