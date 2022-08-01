#pragma once

#include <core/StyleSheet.h>
#include <core/Types.h>
#include <core/PropertyDictionary.h>
#include <core/StyleCache.h>

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

struct StyleSheetRequirements {
	std::string tag;
	std::string id;
	std::vector<std::string> class_names;
	PseudoClassSet pseudo_classes = 0;
	StructuralSelectorList structural_selectors; // Represents structural pseudo classes
	bool child_combinator = false; // The '>' combinator: This node only matches if the element is a parent of the previous matching element.

	bool operator==(const StyleSheetRequirements& rhs) const;
	bool Match(const Element* element) const;
	bool MatchStructuralSelector(const Element* element) const;
	int GetSpecificity() const;
};

class StyleSheetNode {
public:
	StyleSheetNode();
	void SetProperties(const PropertyVector& properties, int rule_specificity);
	bool IsApplicable(const Element* element) const;
	int GetSpecificity() const;
	void AddRequirements(StyleSheetRequirements&& req);
	Style::PropertyMap GetProperties() const;

private:
	Style::PropertyMap properties;
	std::vector<StyleSheetRequirements> requirements;
	int specificity = 0;
};

}
