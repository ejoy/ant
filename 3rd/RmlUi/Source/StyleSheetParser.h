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

#ifndef RMLUI_CORE_STYLESHEETPARSER_H
#define RMLUI_CORE_STYLESHEETPARSER_H

#include "../Include/RmlUi/StyleSheet.h"
#include "../Include/RmlUi/Types.h"

namespace Rml {

class Stream;
class StyleSheetNode;
class StyleSheetPropertyDictionary;
using StyleSheetNodeListRaw = std::vector<StyleSheetNode*>;

/**
	Helper class for parsing a style sheet into its memory representation.

	@author Lloyd Weehuizen
 */

class StyleSheetParser
{
public:
	StyleSheetParser();
	~StyleSheetParser();

	/// Parses the given stream into the style sheet
	/// @param node The root node the stream will be parsed into
	/// @param stream The stream to read
	/// @return The number of parsed rules, or -1 if an error occured.
	int Parse(StyleSheetNode* node, Stream* stream, const StyleSheet& style_sheet, KeyframesMap& keyframes, int begin_line_number);

	/// Parses the given string into the property dictionary
	/// @param parsed_properties The properties dictionary the properties will be read into
	/// @param properties The properties to parse
	/// @return True if the parse was successful, or false if an error occured.
	bool ParseProperties(PropertyDictionary& parsed_properties, const std::string& properties);

	// Converts a selector query to a tree of nodes.
	// @param root_node Node to construct into.
	// @param selectors The selector rules as a string value.
	// @return The list of leaf nodes in the constructed tree, which are all owned by the root node.
	static StyleSheetNodeListRaw ConstructNodes(StyleSheetNode& root_node, const std::string& selectors);

private:
	Stream* stream;
	size_t line_number;

	// Parses properties from the parse buffer.
	// @param property_parser An abstract parser which specifies how the properties are parsed and stored.
	bool ReadProperties(PropertyDictionary& properties);

	// Import properties into the stylesheet node
	// @param node Node to import into
	// @param names The names of the nodes
	// @param properties The dictionary of properties
	// @param rule_specificity The specifity of the rule
	// @return The leaf node of the rule
	static StyleSheetNode* ImportProperties(StyleSheetNode* node, std::string rule_name, const StyleSheetPropertyDictionary& properties, int rule_specificity);

	// Attempts to parse a @keyframes block
	bool ParseKeyframeBlock(KeyframesMap & keyframes_map, const std::string & identifier, const std::string & rules, const PropertyDictionary & properties);

	// Attempts to find one of the given character tokens in the active stream
	// If it's found, buffer is filled with all content up until the token
	// @param buffer The buffer that receives the content
	// @param characters The character tokens to find
	// @param remove_token If the token that caused the find to stop should be removed from the stream
	char FindToken(std::string& buffer, const char* tokens, bool remove_token);

	// Attempts to find the next character in the active stream.
	// If it's found, buffer is filled with the character
	// @param buffer The buffer that receives the character, if read.
	bool ReadCharacter(char& buffer);
};

}
#endif
