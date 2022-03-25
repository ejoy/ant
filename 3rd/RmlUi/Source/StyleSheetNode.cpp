/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2008-2010 CodePoint Ltd, Shift Technology Ltd
 * Copyright (c) 2019 The RmlUi Team, and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#include "StyleSheetNode.h"
#include "../Include/RmlUi/Element.h"
#include "StyleSheetFactory.h"
#include "StyleSheetNodeSelector.h"
#include <algorithm>
#include <bit>

namespace Rml {

StyleSheetNode::StyleSheetNode()
{
	CalculateAndSetSpecificity();
}

StyleSheetNode::StyleSheetNode(StyleSheetNode* parent, const std::string& tag, const std::string& id, const std::vector<std::string>& classes, PseudoClassSet pseudo_classes, const StructuralSelectorList& structural_selectors, bool child_combinator)
	: parent(parent)
	, tag(tag)
	, id(id)
	, class_names(classes)
	, pseudo_classes(pseudo_classes)
	, structural_selectors(structural_selectors)
	, child_combinator(child_combinator)
{
	CalculateAndSetSpecificity();
}

StyleSheetNode::StyleSheetNode(StyleSheetNode* parent, std::string&& tag, std::string&& id, std::vector<std::string>&& classes, PseudoClassSet pseudo_classes, StructuralSelectorList&& structural_selectors, bool child_combinator)
	: parent(parent)
	, tag(std::move(tag))
	, id(std::move(id))
	, class_names(std::move(classes))
	, pseudo_classes(pseudo_classes)
	, structural_selectors(std::move(structural_selectors))
	, child_combinator(child_combinator)
{
	CalculateAndSetSpecificity();
}

StyleSheetNode* StyleSheetNode::GetOrCreateChildNode(const StyleSheetNode& other) {
	// See if we match the target child
	for (const auto& child : children) {
		if (child->EqualRequirements(other.tag, other.id, other.class_names, other.pseudo_classes, other.structural_selectors, other.child_combinator))
			return child.get();
	}

	// We don't, so create a new child
	auto child = std::make_unique<StyleSheetNode>(this, other.tag, other.id, other.class_names, other.pseudo_classes, other.structural_selectors, other.child_combinator);
	StyleSheetNode* result = child.get();

	children.push_back(std::move(child));

	return result;
}

StyleSheetNode* StyleSheetNode::GetOrCreateChildNode(std::string&& tag, std::string&& id, std::vector<std::string>&& classes, PseudoClassSet pseudo_classes, StructuralSelectorList&& structural_pseudo_classes, bool child_combinator) {
	// See if we match an existing child
	for (const auto& child : children) {
		if (child->EqualRequirements(tag, id, classes, pseudo_classes, structural_pseudo_classes, child_combinator))
			return child.get();
	}

	// We don't, so create a new child
	auto child = std::make_unique<StyleSheetNode>(this, std::move(tag), std::move(id), std::move(classes), std::move(pseudo_classes), std::move(structural_pseudo_classes), child_combinator);
	StyleSheetNode* result = child.get();

	children.push_back(std::move(child));

	return result;
}

// Merges an entire tree hierarchy into our hierarchy.
void StyleSheetNode::MergeHierarchy(StyleSheetNode* node, int specificity_offset) {
	// Merge the other node's properties into ours.
	node->MergeProperties(properties, specificity_offset);

	for (const auto& other_child : node->children) {
		StyleSheetNode* local_node = GetOrCreateChildNode(*other_child);
		local_node->MergeHierarchy(other_child.get(), specificity_offset);
	}
}

// Builds up a style sheet's index recursively.
void StyleSheetNode::BuildIndex(StyleSheet::NodeIndex& styled_node_index) {
	// If this has properties defined, then we insert it into the styled node index.
	if (!properties.prop.empty()) {
		// The keys of the node index is a hashed combination of tag and id. These are used for fast lookup of applicable nodes.
		size_t node_hash = StyleSheet::NodeHash(tag, id);
		StyleSheet::NodeList& nodes = styled_node_index[node_hash];
		auto it = std::find(nodes.begin(), nodes.end(), this);
		if(it == nodes.end())
			nodes.push_back(this);
	}

	for (auto& child : children) {
		child->BuildIndex(styled_node_index);
	}
}

bool StyleSheetNode::EqualRequirements(const std::string& _tag, const std::string& _id, const std::vector<std::string>& _class_names, PseudoClassSet _pseudo_classes, const StructuralSelectorList& _structural_selectors, bool _child_combinator) const {
	if (tag != _tag)
		return false;
	if (id != _id)
		return false;
	if (class_names != _class_names)
		return false;
	if (pseudo_classes != _pseudo_classes)
		return false;
	if (structural_selectors != _structural_selectors)
		return false;
	if (child_combinator != _child_combinator)
		return false;

	return true;
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

inline bool StyleSheetNode::Match(const Element* element) const {
	if (!tag.empty() && tag != element->GetTagName())
		return false;

	if (!id.empty() && id != element->GetId())
		return false;

	if (!MatchClassPseudoClass(element))
		return false;

	if (!MatchStructuralSelector(element))
		return false;

	return true;
}

inline bool StyleSheetNode::MatchClassPseudoClass(const Element* element) const {
	for (auto& name : class_names) 	{
		if (!element->IsClassSet(name))
			return false;
	}
	return element->IsPseudoClassSet(pseudo_classes);
}

inline bool StyleSheetNode::MatchStructuralSelector(const Element* element) const {
	for (auto& node_selector : structural_selectors) {
		if (!node_selector.selector->IsApplicable(element, node_selector.a, node_selector.b))
			return false;
	}
	
	return true;
}

// Returns true if this node is applicable to the given element, given its IDs, classes and heritage.
bool StyleSheetNode::IsApplicable(const Element* const in_element) const {
	// Determine whether the element matches the current node and its entire lineage. The entire hierarchy of
	// the element's document will be considered during the match as necessary.

	// Id and tag have already been checked, only check class and pseudo class.
	if (!MatchClassPseudoClass(in_element))
		return false;

	const Element* element = in_element;

	// Walk up through all our parent nodes, each one of them must be matched by some ancestor element.
	for (const StyleSheetNode* node = parent; node && node->parent; node = node->parent) {
		// Try a match on every element ancestor. If it succeeds, we continue on to the next node.
		for (element = element->GetParentNode(); element; element = element->GetParentNode()) {
			if (node->Match(element))
				break;
			// If we have a child combinator on the node, we must match this first ancestor.
			else if (node->child_combinator)
				return false;
		}

		// We have run out of element ancestors before we matched every node. Bail out.
		if (!element)
			return false;
	}

	// Finally, check the structural selector requirements last as they can be quite slow.
	if (!MatchStructuralSelector(in_element))
		return false;

	return true;
}

void StyleSheetNode::CalculateAndSetSpecificity() {
	// Calculate the specificity of just this node; tags are worth 10,000, IDs 1,000,000 and other specifiers (classes
	// and pseudo-classes) 100,000.
	specificity = 0;

	if (!tag.empty())
		specificity += 10'000;

	if (!id.empty())
		specificity += 1'000'000;

	specificity += 100'000*(int)class_names.size();
	specificity += 100'000*(int)std::popcount(pseudo_classes);
	specificity += 100'000*(int)structural_selectors.size();

	// Add our parent's specificity onto ours.
	if (parent)
		specificity += parent->specificity;
}

}
