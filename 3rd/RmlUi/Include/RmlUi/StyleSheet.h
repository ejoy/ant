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

#ifndef RMLUI_CORE_STYLESHEET_H
#define RMLUI_CORE_STYLESHEET_H

#include "Traits.h"
#include "Types.h"

namespace Rml {

class Element;
class StyleSheetNode;
class StyleSheetPropertyDictionary;
class Stream;

struct KeyframeBlock {
	float normalized_time;  // [0, 1]
	PropertyDictionary properties;
};
struct Keyframes {
	std::vector<PropertyId> property_ids;
	std::vector<KeyframeBlock> blocks;
};
using KeyframesMap = std::unordered_map<std::string, Keyframes>;

/**
	StyleSheet maintains a single stylesheet definition. A stylesheet can be combined with another stylesheet to create
	a new, merged stylesheet.

	@author Lloyd Weehuizen
 */

class StyleSheet : public NonCopyMoveable
{
public:
	typedef std::vector< StyleSheetNode* > NodeList;
	typedef std::unordered_map< size_t, NodeList > NodeIndex;

	StyleSheet();
	virtual ~StyleSheet();

	/// Loads a style from a CSS definition.
	bool LoadStyleSheet(Stream* stream, int begin_line_number = 1);

	/// Combines this style sheet with another one, producing a new sheet.
	void CombineStyleSheet(const StyleSheet& sheet);
	/// Builds the node index for a combined style sheet.
	void BuildNodeIndex();

	/// Returns the Keyframes of the given name, or null if it does not exist.
	Keyframes* GetKeyframes(const std::string& name);

	/// Returns the compiled element definition for a given element hierarchy. A reference count will be added for the
	/// caller, so another should not be added. The definition should be released by removing the reference count.
	std::shared_ptr<StyleSheetPropertyDictionary> GetElementDefinition(const Element* element) const;

	/// Retrieve the hash key used to look-up applicable nodes in the node index.
	static size_t NodeHash(const std::string& tag, const std::string& id);

private:
	// Root level node, attributes from special nodes like "body" get added to this node
	std::unique_ptr<StyleSheetNode> root;

	// The maximum specificity offset used in this style sheet to distinguish between properties in
	// similarly-specific rules, but declared on different lines. When style sheets are merged, the
	// more-specific style sheet (ie, coming further 'down' the include path) adds the offset of
	// the less-specific style sheet onto its offset, thereby ensuring its properties take
	// precedence in the event of a conflict.
	int specificity_offset;

	// Name of every @keyframes mapped to their keys
	KeyframesMap keyframes;

	// Map of all styled nodes, that is, they have one or more properties.
	NodeIndex styled_node_index;

	using ElementDefinitionCache = std::unordered_map< size_t, std::shared_ptr<StyleSheetPropertyDictionary> >;
	// Index of node sets to element definitions.
	mutable ElementDefinitionCache node_cache;
};

} // namespace Rml
#endif
