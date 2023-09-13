#include <core/Node.h>
#include <core/Element.h>

namespace Rml {

Node::Node(Type type)
	: type(type)
{}

Node::~Node()
{}

void Node::ResetParentNode() {
	parent = nullptr;
}

Element* Node::GetParentNode() const {
	return parent;
}

Node::Type Node::GetType() const {
	return type;
}

void Node::SetParentNode(Element* _parent) {
	assert(_parent);
	parent = _parent;
}

LayoutNode::LayoutNode(Layout::UseElement use)
	: Node(Node::Type::Element)
	, layout(use)
{}

LayoutNode::LayoutNode(Layout::UseText use, void* context)
	: Node(Node::Type::Text)
	, layout(use, context)
{}

bool LayoutNode::UpdateLayout() {
	if (layout.HasNewLayout()) {
		visible = layout.IsVisible();
		if (visible) {
			bounds = layout.GetBounds();
			CalculateLayout();
		}
	}
	return visible;
}

Layout& LayoutNode::GetLayout() {
	return layout;
}

const Layout& LayoutNode::GetLayout() const {
	return layout;
}

bool LayoutNode::IsVisible() const {
	return visible;
}

void LayoutNode::SetVisible(bool visible) {
	layout.SetVisible(visible);
}

const Rect& LayoutNode::GetBounds() const {
	return bounds;
}

void LayoutNode::InsertChild(const LayoutNode* child, size_t index) {
	layout.InsertChild(child->layout, index);
}

void LayoutNode::RemoveChild(const LayoutNode* child) {
	layout.RemoveChild(child->layout);
}

}
