#include <core/StyleSheetNodeSelector.h>
#include <core/Element.h>
#include <core/Text.h>

namespace Rml {

template <typename T>
struct reversion_wrapper {
	auto begin() { return std::rbegin(iterable); }
	auto end () { return std::rend(iterable); }
	T& iterable;
};
template <typename T>
reversion_wrapper<T> reverse(T&& iterable) { return { iterable }; }

static bool IsNth(int a, int b, int count) {
	int x = count;
	x -= b;
	if (a != 0)
		x /= a;
	return (x >= 0 && x * a + b == count);
}

bool StyleSheetNodeSelectorEmpty::IsApplicable(const Element* element, int, int) {
	for (const Element* child : element->Children()) {
		if (child->IsVisible())
			return false;
	}
	return true;
}

bool StyleSheetNodeSelectorFirstChild::IsApplicable(const Element* element, int, int) {
	Element* parent = element->GetParentNode();
	if (parent == nullptr)
		return false;
	for (const Element* child : parent->Children()) {
		if (child == element)
			return true;
		return false;
	}
	return false;
}

bool StyleSheetNodeSelectorFirstOfType::IsApplicable(const Element* element, int, int) {
	Element* parent = element->GetParentNode();
	if (parent == nullptr)
		return false;
	for (const Element* child : parent->Children()) {
		if (child == element)
			return true;
		if (child->GetTagName() == element->GetTagName() && child->IsVisible())
			return false;
	}
	return false;
}

bool StyleSheetNodeSelectorLastChild::IsApplicable(const Element* element, int, int) {
	Element* parent = element->GetParentNode();
	if (parent == nullptr)
		return false;
	for (const Element* child : reverse(parent->Children())) {
		if (child == element)
			return true;
		return false;
	}
	return false;
}

bool StyleSheetNodeSelectorLastOfType::IsApplicable(const Element* element, int, int) {
	Element* parent = element->GetParentNode();
	if (parent == nullptr)
		return false;
	for (const Element* child : reverse(parent->Children())) {
		if (child == element)
			return true;
		if (child->GetTagName() == element->GetTagName() && child->IsVisible())
			return false;
	}
	return false;
}

bool StyleSheetNodeSelectorNthChild::IsApplicable(const Element* element, int a, int b) {
	Element* parent = element->GetParentNode();
	if (parent == nullptr)
		return false;
	int element_index = 1;
	for (const Element* child : parent->Children()) {
		if (child == element)
			break;
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
	int element_index = 1;
	for (const Element* child : reverse(parent->Children())) {
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
	int element_index = 1;
	for (const Element* child : reverse(parent->Children())) {
		if (child == element)
			break;
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
	int element_index = 1;
	for (const Element* child : parent->Children()) {
		if (child == element)
			break;
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
	for (const Element* child : parent->Children()) {
		if (child == element)
			continue;
		if (!child->IsVisible())
			continue;
		return false;
	}
	return true;
}

bool StyleSheetNodeSelectorOnlyOfType::IsApplicable(const Element* element, int, int) {
	Element* parent = element->GetParentNode();
	if (parent == nullptr)
		return false;
	for (const Element* child : parent->Children()) {
		if (child == element)
			continue;
		if (child->GetTagName() != element->GetTagName() || !child->IsVisible())
			continue;
		return false;
	}
	return true;
}

}
