#pragma once

#include <core/Types.h>
#include <css/StyleSheet.h>
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
	StyleSheetRequirements(const std::string& name);
	bool operator==(const StyleSheetRequirements& rhs) const;
	bool Match(const Element* element) const;
	bool MatchStructuralSelector(const Element* element) const;
	int GetSpecificity() const;
};

class StyleSheetNode {
public:
	StyleSheetNode(const std::string& rule_name, const Style::TableRef& props);
	void SetSpecificity(int rule_specificity);
	bool IsApplicable(const Element* element) const;
	int GetSpecificity() const;
	const Style::TableRef& GetProperties() const;
private:
	void ImportRequirements(std::string rule_name);
private:
	Style::TableRef properties;
	std::vector<StyleSheetRequirements> requirements;
	int specificity = 0;
};

}
