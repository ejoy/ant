#include <core/StyleSheetNode.h>
#include <core/Element.h>
#include <core/StyleSheetFactory.h>
#include <core/StyleSheetNodeSelector.h>
#include <algorithm>
#include <bit>

namespace Rml {

bool StyleSheetRequirements::operator==(const StyleSheetRequirements& rhs) const {
	if (tag != rhs.tag)
		return false;
	if (id != rhs.id)
		return false;
	if (class_names != rhs.class_names)
		return false;
	if (pseudo_classes != rhs.pseudo_classes)
		return false;
	if (structural_selectors != rhs.structural_selectors)
		return false;
	if (child_combinator != rhs.child_combinator)
		return false;
	return true;
}

bool StyleSheetRequirements::Match(const Element* element) const {
	if (!tag.empty() && tag != element->GetTagName())
		return false;
	if (!id.empty() && id != element->GetId())
		return false;
	for (auto& name : class_names) 	{
		if (!element->IsClassSet(name))
			return false;
	}
	return element->IsPseudoClassSet(pseudo_classes);
}

int StyleSheetRequirements::GetSpecificity() {
	int specificity = 0;
	if (!tag.empty())
		specificity += 10'000;
	if (!id.empty())
		specificity += 1'000'000;
	specificity += 100'000*(int)class_names.size();
	specificity += 100'000*(int)std::popcount(pseudo_classes);
	specificity += 100'000*(int)structural_selectors.size();
	return specificity;
}

StyleSheetNode::StyleSheetNode()
{
	CalculateAndSetSpecificity();
}

StyleSheetNode::StyleSheetNode(StyleSheetNode* parent, StyleSheetRequirements const& req)
	: parent(parent)
	, requirements(req)
{
	CalculateAndSetSpecificity();
}

StyleSheetNode::StyleSheetNode(StyleSheetNode* parent, StyleSheetRequirements && req)
	: parent(parent)
	, requirements(std::move(req))
{
	CalculateAndSetSpecificity();
}

StyleSheetNode* StyleSheetNode::GetOrCreateChildNode(const StyleSheetNode& other) {
	for (const auto& child : children) {
		if (child->requirements == other.requirements)
			return child.get();
	}
	auto child = std::make_unique<StyleSheetNode>(this, other.requirements);
	StyleSheetNode* result = child.get();
	children.push_back(std::move(child));
	return result;
}

StyleSheetNode* StyleSheetNode::GetOrCreateChildNode(StyleSheetRequirements && requirements) {
	for (const auto& child : children) {
		if (child->requirements == requirements)
			return child.get();
	}
	auto child = std::make_unique<StyleSheetNode>(this, std::move(requirements));
	StyleSheetNode* result = child.get();
	children.push_back(std::move(child));
	return result;
}

void StyleSheetNode::MergeHierarchy(StyleSheetNode* node, int specificity_offset) {
	node->MergeProperties(properties, specificity_offset);
	for (const auto& other_child : node->children) {
		StyleSheetNode* local_node = GetOrCreateChildNode(*other_child);
		local_node->MergeHierarchy(other_child.get(), specificity_offset);
	}
}

void StyleSheetNode::BuildIndex(StyleSheet::NodeIndex& styled_node_index) {
	if (!properties.prop.empty()) {
		styled_node_index.push_back(this);
	}
	for (auto& child : children) {
		child->BuildIndex(styled_node_index);
	}
}

int StyleSheetNode::GetSpecificity() const {
	return specificity;
}

static int getSpecificity(const StyleSheetPropertyDictionary& properties, PropertyId id) {
	int specificity = -1;
	auto itSpec = properties.spec.find(id);
	if (itSpec != properties.spec.end()) {
		specificity = itSpec->second;
	}
	return specificity;
}

static void SetProperty(StyleSheetPropertyDictionary& properties, PropertyId id, const Property& property, int specificity) {
	auto it = properties.prop.find(id);
	if (it != properties.prop.end() && getSpecificity(properties, id) > specificity) {
		return;
	}
	properties.prop.insert_or_assign(id, property);
	properties.spec.insert_or_assign(id, specificity);
}

void StyleSheetNode::ImportProperties(const StyleSheetPropertyDictionary& _properties, int rule_specificity) {
	int property_specificity = specificity + rule_specificity;
	for (const auto& [id, property] : _properties.prop) {
		int specificity = getSpecificity(_properties, id);
		SetProperty(properties, id, property, property_specificity > 0 ? property_specificity : specificity);
	}
}

void StyleSheetNode::MergeProperties(StyleSheetPropertyDictionary& _properties, int specificity_offset) const {
	for (const auto& [id, property] : properties.prop) {
		int specificity = getSpecificity(properties, id);
		SetProperty(_properties, id, property, specificity + specificity_offset);
	}
}

bool StyleSheetNode::Match(const Element* element) const {
	return requirements.Match(element);
}

bool StyleSheetNode::MatchStructuralSelector(const Element* element) const {
	for (auto& node_selector : requirements.structural_selectors) {
		if (!node_selector.selector->IsApplicable(element, node_selector.a, node_selector.b))
			return false;
	}
	return true;
}

bool StyleSheetNode::IsApplicable(const Element* const in_element) const {
	if (!Match(in_element))
		return false;
	const Element* element = in_element;
	// Walk up through all our parent nodes, each one of them must be matched by some ancestor element.
	for (const StyleSheetNode* node = parent; node && node->parent; node = node->parent) {
		// Try a match on every element ancestor. If it succeeds, we continue on to the next node.
		for (element = element->GetParentNode(); element; element = element->GetParentNode()) {
			if (node->Match(element) && node->MatchStructuralSelector(element))
				break;
			// If we have a child combinator on the node, we must match this first ancestor.
			else if (node->requirements.child_combinator)
				return false;
		}
		// We have run out of element ancestors before we matched every node. Bail out.
		if (!element)
			return false;
	}
	return MatchStructuralSelector(in_element);
}

void StyleSheetNode::CalculateAndSetSpecificity() {
	specificity = requirements.GetSpecificity();
	if (parent)
		specificity += parent->specificity;
}

}
