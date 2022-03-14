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

#include "../Include/RmlUi/StyleSheet.h"
#include "StyleSheetFactory.h"
#include "StyleSheetNode.h"
#include "StyleSheetParser.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/Factory.h"
#include "../Include/RmlUi/PropertyDefinition.h"
#include "../Include/RmlUi/StyleSheetSpecification.h"
#include "../Include/RmlUi/Types.h"
#include "../Include/RmlUi/Property.h"
#include <algorithm>

namespace Rml {

template <class T>
inline void HashCombine(std::size_t& seed, const T& v)
{
	std::hash<T> hasher;
	seed ^= hasher(v) + 0x9e3779b9 + (seed << 6) + (seed >> 2);
}

// Sorts style nodes based on specificity.
inline static bool StyleSheetNodeSort(const StyleSheetNode* lhs, const StyleSheetNode* rhs)
{
	return lhs->GetSpecificity() < rhs->GetSpecificity();
}

StyleSheet::StyleSheet()
{
	root = std::make_unique<StyleSheetNode>();
	specificity_offset = 0;
}

StyleSheet::~StyleSheet()
{
}

bool StyleSheet::LoadStyleSheet(Stream* stream, int begin_line_number)
{
	StyleSheetParser parser;
	specificity_offset = parser.Parse(root.get(), stream, *this, keyframes, begin_line_number);
	return specificity_offset >= 0;
}

/// Combines this style sheet with another one, producing a new sheet
void StyleSheet::CombineStyleSheet(const StyleSheet& other_sheet)
{
	root->MergeHierarchy(other_sheet.root.get(), specificity_offset);

	// Any matching @keyframe names are overridden as per CSS rules
	keyframes.reserve(keyframes.size() + other_sheet.keyframes.size());
	for (auto& other_keyframes : other_sheet.keyframes)
	{
		keyframes[other_keyframes.first] = other_keyframes.second;
	}

	specificity_offset += other_sheet.specificity_offset;
}

// Builds the node index for a combined style sheet.
void StyleSheet::BuildNodeIndex()
{
	styled_node_index.clear();
	root->BuildIndex(styled_node_index);
	root->SetStructurallyVolatileRecursive(false);
}

// Returns the Keyframes of the given name, or null if it does not exist.
Keyframes * StyleSheet::GetKeyframes(const std::string & name)
{
	auto it = keyframes.find(name);
	if (it != keyframes.end())
		return &(it->second);
	return nullptr;
}

size_t StyleSheet::NodeHash(const std::string& tag, const std::string& id)
{
	size_t seed = 0;
	if (!tag.empty())
		seed = std::hash<std::string>()(tag);
	if(!id.empty())
		HashCombine(seed, id);
	return seed;
}

// Returns the compiled element definition for a given element hierarchy.
std::shared_ptr<StyleSheetPropertyDictionary> StyleSheet::GetElementDefinition(const Element* element) const
{
	// See if there are any styles defined for this element.
	// Using static to avoid allocations. Make sure we don't call this function recursively.
	static std::vector< const StyleSheetNode* > applicable_nodes;
	applicable_nodes.clear();

	const std::string& tag = element->GetTagName();
	const std::string& id = element->GetId();

	// The styled_node_index is hashed with the tag and id of the RCSS rule. However, we must also check
	// the rules which don't have them defined, because they apply regardless of tag and id.
	std::array<size_t, 4> node_hash;
	int num_hashes = 2;

	node_hash[0] = 0;
	node_hash[1] = NodeHash(tag, std::string());

	// If we don't have an id, we can safely skip nodes that define an id. Otherwise, we also check the id nodes.
	if (!id.empty())
	{
		num_hashes = 4;
		node_hash[2] = NodeHash(std::string(), id);
		node_hash[3] = NodeHash(tag, id);
	}

	// The hashes are keys into a set of applicable nodes (given tag and id).
	for (int i = 0; i < num_hashes; i++)
	{
		auto it_nodes = styled_node_index.find(node_hash[i]);
		if (it_nodes != styled_node_index.end())
		{
			const NodeList& nodes = it_nodes->second;

			// Now see if we satisfy all of the requirements not yet tested: classes, pseudo classes, structural selectors, 
			// and the full requirements of parent nodes. What this involves is traversing the style nodes backwards, 
			// trying to match nodes in the element's hierarchy to nodes in the style hierarchy.
			for (StyleSheetNode* node : nodes)
			{
				if (node->IsApplicable(element, true))
				{
					applicable_nodes.push_back(node);
				}
			}
		}
	}

	std::sort(applicable_nodes.begin(), applicable_nodes.end(), StyleSheetNodeSort);

	// If this element definition won't actually store any information, don't bother with it.
	if (applicable_nodes.empty())
		return nullptr;

	// Check if this puppy has already been cached in the node index.
	size_t seed = 0;
	for (const StyleSheetNode* node : applicable_nodes)
		HashCombine(seed, node);

	auto cache_iterator = node_cache.find(seed);
	if (cache_iterator != node_cache.end())
	{
		std::shared_ptr<StyleSheetPropertyDictionary>& definition = (*cache_iterator).second;
		return definition;
	}

	auto new_definition = std::make_shared<StyleSheetPropertyDictionary>();
	for (auto const& node : applicable_nodes) {
		node->MergeProperties(*new_definition);
	}

	// Create the new definition and add it to our cache.
	node_cache[seed] = new_definition;

	return new_definition;
}

} // namespace Rml
