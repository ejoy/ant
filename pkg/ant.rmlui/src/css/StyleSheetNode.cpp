#include <css/StyleSheetNode.h>
#include <core/Element.h>
#include <css/StyleSheetNodeSelector.h>
#include <css/StyleCache.h>
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

bool StyleSheetRequirements::MatchStructuralSelector(const Element* element) const {
	for (auto& node_selector : structural_selectors) {
		if (!node_selector.selector(element, node_selector.a, node_selector.b))
			return false;
	}
	return true;
}

int StyleSheetRequirements::GetSpecificity() const {
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
{}

int StyleSheetNode::GetSpecificity() const {
	return specificity;
}

void StyleSheetNode::SetProperties(const PropertyVector& prop) {
	properties = Style::Instance().Create(prop);
}

void StyleSheetNode::SetSpecificity(int rule_specificity) {
	specificity = rule_specificity;
	for (auto const& req : requirements) {
		specificity += req.GetSpecificity();
	}
}

bool StyleSheetNode::IsApplicable(const Element* const in_element) const {
	if (!requirements[0].Match(in_element))
		return false;
	const Element* element = in_element;
	// Walk up through all our parent nodes, each one of them must be matched by some ancestor element.
	for (size_t i = 1; i < requirements.size(); ++i) {
		auto const& req = requirements[i];
		// Try a match on every element ancestor. If it succeeds, we continue on to the next node.
		for (element = element->GetParentNode(); element; element = element->GetParentNode()) {
			if (req.Match(element) && req.MatchStructuralSelector(element))
				break;
			// If we have a child combinator on the node, we must match this first ancestor.
			else if (req.child_combinator)
				return false;
		}
		// We have run out of element ancestors before we matched every node. Bail out.
		if (!element)
			return false;
	}
	return requirements[0].MatchStructuralSelector(in_element);
}

void StyleSheetNode::AddRequirements(StyleSheetRequirements&& req) {
	requirements.emplace_back(req);
}

Style::TableValue StyleSheetNode::GetProperties() const {
	return properties;
}

}
