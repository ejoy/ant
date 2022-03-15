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

#ifndef RMLUI_CORE_STYLESHEETNODE_H
#define RMLUI_CORE_STYLESHEETNODE_H

#include "../Include/RmlUi/StyleSheet.h"
#include "../Include/RmlUi/Types.h"
#include <tuple>

namespace Rml {

class StyleSheetNodeSelector;

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


/**
	A style sheet is composed of a tree of nodes.

	@author Pete / Lloyd
 */

class StyleSheetPropertyDictionary {
public:
	PropertyDictionary                  prop;
	std::unordered_map<PropertyId, int> spec;
};

class StyleSheetNode
{
public:
	StyleSheetNode();
	StyleSheetNode(StyleSheetNode* parent, const std::string& tag, const std::string& id, const std::vector<std::string>& classes, PseudoClassSet pseudo_classes, const StructuralSelectorList& structural_selectors, bool child_combinator);
	StyleSheetNode(StyleSheetNode* parent, std::string&& tag, std::string&& id, std::vector<std::string>&& classes, PseudoClassSet pseudo_classes, StructuralSelectorList&& structural_selectors, bool child_combinator);

	/// Retrieves a child node with the given requirements if they match an existing node, or else creates a new one.
	StyleSheetNode* GetOrCreateChildNode(std::string&& tag, std::string&& id, std::vector<std::string>&& classes, PseudoClassSet pseudo_classes, StructuralSelectorList&& structural_selectors, bool child_combinator);
	/// Retrieves or creates a child node with requirements equivalent to the 'other' node.
	StyleSheetNode* GetOrCreateChildNode(const StyleSheetNode& other);

	/// Merges an entire tree hierarchy into our hierarchy.
	void MergeHierarchy(StyleSheetNode* node, int specificity_offset = 0);
	/// Recursively set structural volatility.
	bool SetStructurallyVolatileRecursive(bool ancestor_is_structurally_volatile);
	/// Builds up a style sheet's index recursively.
	void BuildIndex(StyleSheet::NodeIndex& styled_node_index);

	void ImportProperties(const StyleSheetPropertyDictionary& properties, int rule_specificity);
	void MergeProperties(StyleSheetPropertyDictionary& properties, int specificity_offset = 0) const;

	/// Returns true if this node is applicable to the given element, given its IDs, classes and heritage.
	bool IsApplicable(const Element* element, bool skip_id_tag) const;

	/// Returns the specificity of this node.
	int GetSpecificity() const;
	/// Returns true if this node employs a structural selector, and therefore generates element definitions that are
	/// sensitive to sibling changes. 
	/// @warning Result is only valid if structural volatility is set since any changes to the node tree.
	bool IsStructurallyVolatile() const;

private:
	// Returns true if the requirements of this node equals the given arguments.
	bool EqualRequirements(const std::string& tag, const std::string& id, const std::vector<std::string>& classes, PseudoClassSet pseudo_classes, const StructuralSelectorList& structural_pseudo_classes, bool child_combinator) const;

	void CalculateAndSetSpecificity();

	// Match an element to the local node requirements.
	inline bool Match(const Element* element) const;
	inline bool MatchClassPseudoClass(const Element* element) const;
	inline bool MatchStructuralSelector(const Element* element) const;

	// The parent of this node; is nullptr for the root node.
	StyleSheetNode* parent = nullptr;

	// Node requirements
	std::string tag;
	std::string id;
	std::vector<std::string> class_names;
	PseudoClassSet pseudo_classes;
	StructuralSelectorList structural_selectors; // Represents structural pseudo classes
	bool child_combinator = false; // The '>' combinator: This node only matches if the element is a parent of the previous matching element.

	// True if any ancestor, descendent, or self is a structural pseudo class.
	bool is_structurally_volatile = true;

	// A measure of specificity of this node; the attribute in a node with a higher value will override those of a
	// node with a lower value.
	int specificity = 0;

	StyleSheetPropertyDictionary properties;

	StyleSheetNodeList children;
};

} // namespace Rml
#endif
