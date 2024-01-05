#pragma once

#include <core/Types.h>
#include <css/StyleSheet.h>
#include <css/PropertyVector.h>
#include <css/StyleCache.h>
#include <css/StyleSheetNodeSelector.h>

namespace Rml {

struct StructuralSelector {
	StructuralSelector(IsApplicable selector, int a, int b) : selector(selector), a(a), b(b) {}
	IsApplicable selector;
	int a;
	int b;
};
inline bool operator==(const StructuralSelector& a, const StructuralSelector& b) { return a.selector == b.selector && a.a == b.a && a.b == b.b; }
inline bool operator<(const StructuralSelector& a, const StructuralSelector& b) { return std::tie(a.selector, a.a, a.b) < std::tie(b.selector, b.a, b.b); }

using StructuralSelectorList = std::vector<StructuralSelector>;

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
	void AddRequirements(StyleSheetRequirements&& req);
	void SetProperties(const PropertyVector& properties);
	void SetSpecificity(int rule_specificity);
	bool IsApplicable(const Element* element) const;
	int GetSpecificity() const;
	Style::TableValue GetProperties() const;

private:
	Style::TableValue properties;
	std::vector<StyleSheetRequirements> requirements;
	int specificity = 0;
};

}
