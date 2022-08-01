#pragma once

#include <core/StyleSheet.h>
#include <core/Types.h>
#include <core/PropertyDictionary.h>

namespace Rml {

struct StyleSheetNodeSelector;

struct StructuralSelector {
	StructuralSelector(StyleSheetNodeSelector* selector, int a, int b) : selector(selector), a(a), b(b) {}
	StyleSheetNodeSelector* selector;
	int a;
	int b;
};
inline bool operator==(const StructuralSelector& a, const StructuralSelector& b) { return a.selector == b.selector && a.a == b.a && a.b == b.b; }
inline bool operator<(const StructuralSelector& a, const StructuralSelector& b) { return std::tie(a.selector, a.a, a.b) < std::tie(b.selector, b.a, b.b); }

using StructuralSelectorList = std::vector< StructuralSelector >;
using StyleSheetNodeList = std::vector< std::unique_ptr<StyleSheetNode> >;

class StyleSheetPropertyDictionary {
public:
	PropertyDictionary                  prop;
	std::unordered_map<PropertyId, int> spec;
};

struct StyleSheetRequirements {
	std::string tag;
	std::string id;
	std::vector<std::string> class_names;
	PseudoClassSet pseudo_classes = 0;
	StructuralSelectorList structural_selectors; // Represents structural pseudo classes
	bool child_combinator = false; // The '>' combinator: This node only matches if the element is a parent of the previous matching element.

	bool operator==(const StyleSheetRequirements& rhs) const;
	bool Match(const Element* element) const;
	int GetSpecificity();
};

class StyleSheetNode {
public:
	StyleSheetNode();
	StyleSheetNode(StyleSheetNode* parent, StyleSheetRequirements const& req);
	StyleSheetNode(StyleSheetNode* parent, StyleSheetRequirements && req);

	StyleSheetNode* GetOrCreateChildNode(StyleSheetRequirements && other);
	StyleSheetNode* GetOrCreateChildNode(StyleSheetNode const& other);

	void MergeHierarchy(StyleSheetNode* node, int specificity_offset = 0);
	void BuildIndex(StyleSheet::NodeIndex& styled_node_index);

	void ImportProperties(const PropertyVector& properties, int rule_specificity);
	void MergeProperties(StyleSheetPropertyDictionary& properties, int specificity_offset = 0) const;
	bool IsApplicable(const Element* element) const;
	int GetSpecificity() const;

private:
	void CalculateAndSetSpecificity();
	bool Match(const Element* element) const;
	bool MatchStructuralSelector(const Element* element) const;
	StyleSheetNode* parent = nullptr;
	StyleSheetRequirements requirements;
	int specificity = 0;
	StyleSheetPropertyDictionary properties;
	StyleSheetNodeList children;
};

}
