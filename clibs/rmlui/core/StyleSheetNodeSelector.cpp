#include "StyleSheetNodeSelector.h"
#include "core/Element.h"
#include "core/Text.h"

namespace Rml {

static bool IsNth(int a, int b, int count) {
	int x = count;
	x -= b;
	if (a != 0)
		x /= a;
	return (x >= 0 && x * a + b == count);
}

bool StyleSheetNodeSelectorEmpty::IsApplicable(const Element* element, int, int) {
	for (int i = 0; i < element->GetNumChildren(); ++i) {
		if (element->GetChild(i)->IsVisible())
			return false;
	}
	return true;
}

bool StyleSheetNodeSelectorFirstChild::IsApplicable(const Element* element, int, int) {
	Element* parent = element->GetParentNode();
	if (parent == nullptr)
		return false;
	int child_index = 0;
	while (child_index < parent->GetNumChildren()) {
		// If this child (the first non-text child) is our element, then the selector succeeds.
		Element* child = parent->GetChild(child_index);
		if (child == element)
			return true;
		// If this child is not a text element, then the selector fails; this element is non-trivial.
		if (dynamic_cast< Text* >(child) == nullptr && child->IsVisible())
			return false;
		// Otherwise, skip over the text element to find the last non-trivial element.
		child_index++;
	}
	return false;
}

bool StyleSheetNodeSelectorFirstOfType::IsApplicable(const Element* element, int, int) {
	Element* parent = element->GetParentNode();
	if (parent == nullptr)
		return false;
	int child_index = 0;
	while (child_index < parent->GetNumChildren()) {
		// If this child is our element, then it's the first one we've found with our tag; the selector succeeds.
		Element* child = parent->GetChild(child_index);
		if (child == element)
			return true;
		// Otherwise, if this child shares our element's tag, then our element is not the first tagged child; the
		// selector fails.
		if (child->GetTagName() == element->GetTagName() && child->IsVisible())
			return false;
		child_index++;
	}
	return false;
}

bool StyleSheetNodeSelectorLastChild::IsApplicable(const Element* element, int, int) {
	Element* parent = element->GetParentNode();
	if (parent == nullptr)
		return false;
	int child_index = parent->GetNumChildren() - 1;
	while (child_index >= 0) {
		// If this child (the last non-text child) is our element, then the selector succeeds.
		Element* child = parent->GetChild(child_index);
		if (child == element)
			return true;
		// If this child is not a text element, then the selector fails; this element is non-trivial.
		if (dynamic_cast< Text* >(child) == nullptr && child->IsVisible())
			return false;
		// Otherwise, skip over the text element to find the last non-trivial element.
		child_index--;
	}
	return false;
}

bool StyleSheetNodeSelectorLastOfType::IsApplicable(const Element* element, int, int) {
	Element* parent = element->GetParentNode();
	if (parent == nullptr)
		return false;
	int child_index = parent->GetNumChildren() - 1;
	while (child_index >= 0) {
		// If this child is our element, then it's the first one we've found with our tag; the selector succeeds.
		Element* child = parent->GetChild(child_index);
		if (child == element)
			return true;
		// Otherwise, if this child shares our element's tag, then our element is not the first tagged child; the
		// selector fails.
		if (child->GetTagName() == element->GetTagName() && child->IsVisible())
			return false;
		child_index--;
	}
	return false;
}

bool StyleSheetNodeSelectorNthChild::IsApplicable(const Element* element, int a, int b) {
	Element* parent = element->GetParentNode();
	if (parent == nullptr)
		return false;
	// Start counting elements until we find this one.
	int element_index = 1;
	for (int i = 0; i < parent->GetNumChildren(); i++) {
		Element* child = parent->GetChild(i);
		// Skip text nodes.
		if (dynamic_cast< Text* >(child) != nullptr)
			continue;
		// If we've found our element, then break; the current index is our element's index.
		if (child == element)
			break;
		// Skip nodes without a display type.
		if (!child->IsVisible())
			continue;
		element_index++;
	}
	return IsNth(a, b, element_index);
}

bool StyleSheetNodeSelectorNthLastChild::IsApplicable(const Element* element, int a, int b) {
	Element* parent = element->GetParentNode();
	if (parent == nullptr)
		return false;
	// Start counting elements until we find this one.
	int element_index = 1;
	for (int i = parent->GetNumChildren() - 1; i >= 0; --i) {
		Element* child = parent->GetChild(i);
		// Skip text nodes.
		if (dynamic_cast< Text* >(child) != nullptr)
			continue;
		// If we've found our element, then break; the current index is our element's index.
		if (child == element)
			break;
		if (!child->IsVisible())
			continue;
		element_index++;
	}
	return IsNth(a, b, element_index);
}

bool StyleSheetNodeSelectorNthLastOfType::IsApplicable(const Element* element, int a, int b) {
	Element* parent = element->GetParentNode();
	if (parent == nullptr)
		return false;
	// Start counting elements until we find this one.
	int element_index = 1;
	for (int i = parent->GetNumChildren() - 1; i >= 0; --i) {
		Element* child = parent->GetChild(i);
		// If we've found our element, then break; the current index is our element's index.
		if (child == element)
			break;
		// Skip nodes that don't share our tag.
		if (child->GetTagName() != element->GetTagName() || !child->IsVisible())
			continue;
		element_index++;
	}
	return IsNth(a, b, element_index);
}

bool StyleSheetNodeSelectorNthOfType::IsApplicable(const Element* element, int a, int b) {
	Element* parent = element->GetParentNode();
	if (parent == nullptr)
		return false;
	// Start counting elements until we find this one.
	int element_index = 1;
	for (int i = 0; i < parent->GetNumChildren(); ++i) {
		Element* child = parent->GetChild(i);
		// If we've found our element, then break; the current index is our element's index.
		if (child == element)
			break;
		// Skip nodes that don't share our tag.
		if (child->GetTagName() != element->GetTagName() || !child->IsVisible())
			continue;
		element_index++;
	}
	return IsNth(a, b, element_index);
}

bool StyleSheetNodeSelectorOnlyChild::IsApplicable(const Element* element, int, int) {
	Element* parent = element->GetParentNode();
	if (parent == nullptr)
		return false;
	for (int i = 0; i < parent->GetNumChildren(); ++i) {
		Element* child = parent->GetChild(i);
		// Skip the child if it is our element.
		if (child == element)
			continue;
		// Skip the child if it is trivial.
		if (dynamic_cast< const Text* >(element) != nullptr || !child->IsVisible())
			continue;
		return false;
	}
	return true;
}

bool StyleSheetNodeSelectorOnlyOfType::IsApplicable(const Element* element, int, int) {
	Element* parent = element->GetParentNode();
	if (parent == nullptr)
		return false;
	for (int i = 0; i < parent->GetNumChildren(); ++i) {
		Element* child = parent->GetChild(i);
		// Skip the child if it is our element.
		if (child == element)
			continue;
		// Skip the child if it does not share our tag.
		if (child->GetTagName() != element->GetTagName() || !child->IsVisible())
			continue;
		// We've found a similarly-tagged child to our element; selector fails.
		return false;
	}
	return true;
}

}
