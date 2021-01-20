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

#include "StyleSheetParser.h"
#include "StyleSheetFactory.h"
#include "StyleSheetNode.h"
#include "../Include/RmlUi/Math.h"
#include "../Include/RmlUi/Factory.h"
#include "../Include/RmlUi/Log.h"
#include "../Include/RmlUi/PropertyDefinition.h"
#include "../Include/RmlUi/PropertySpecification.h"
#include "../Include/RmlUi/StreamMemory.h"
#include "../Include/RmlUi/StyleSheet.h"
#include "../Include/RmlUi/StyleSheetSpecification.h"
#include <algorithm>
#include <string.h>

namespace Rml {

class AbstractPropertyParser {
public:
	virtual bool Parse(const String& name, const String& value) = 0;
};

/*
 *  PropertySpecificationParser just passes the parsing to a property specification. Usually
 *    the main stylesheet specification.
*/
class PropertySpecificationParser final : public AbstractPropertyParser {
private:
	// The dictionary to store the properties in.
	PropertyDictionary& properties;

	// The specification used to parse the values. Normally the default stylesheet specification.
	const PropertySpecification& specification;

public:
	PropertySpecificationParser(PropertyDictionary& properties, const PropertySpecification& specification) : properties(properties), specification(specification) {}

	bool Parse(const String& name, const String& value) override
	{
		return specification.ParsePropertyDeclaration(properties, name, value);
	}
};

StyleSheetParser::StyleSheetParser()
{
	line_number = 0;
	stream = nullptr;
	parse_buffer_pos = 0;
}

StyleSheetParser::~StyleSheetParser()
{
}

void StyleSheetParser::Initialise()
{
}

void StyleSheetParser::Shutdown()
{
}

static bool IsValidIdentifier(const String& str)
{
	if (str.empty())
		return false;

	for (size_t i = 0; i < str.size(); i++)
	{
		char c = str[i];
		bool valid = (
			(c >= 'a' && c <= 'z')
			|| (c >= 'A' && c <= 'Z')
			|| (c >= '0' && c <= '9')
			|| (c == '-')
			|| (c == '_')
			);
		if (!valid)
			return false;
	}

	return true;
}


static void PostprocessKeyframes(KeyframesMap& keyframes_map)
{
	for (auto& keyframes_pair : keyframes_map)
	{
		Keyframes& keyframes = keyframes_pair.second;
		auto& blocks = keyframes.blocks;
		auto& property_ids = keyframes.property_ids;

		// Sort keyframes on selector value.
		std::sort(blocks.begin(), blocks.end(), [](const KeyframeBlock& a, const KeyframeBlock& b) { return a.normalized_time < b.normalized_time; });

		// Add all property names specified by any block
		if(blocks.size() > 0) property_ids.reserve(blocks.size() * blocks[0].properties.GetNumProperties());
		for(auto& block : blocks)
		{
			for (auto& property : block.properties.GetProperties())
				property_ids.push_back(property.first);
		}
		// Remove duplicate property names
		std::sort(property_ids.begin(), property_ids.end());
		property_ids.erase(std::unique(property_ids.begin(), property_ids.end()), property_ids.end());
		property_ids.shrink_to_fit();
	}

}


bool StyleSheetParser::ParseKeyframeBlock(KeyframesMap& keyframes_map, const String& identifier, const String& rules, const PropertyDictionary& properties)
{
	if (!IsValidIdentifier(identifier))
	{
		Log::Message(Log::LT_WARNING, "Invalid keyframes identifier '%s' at %s:%d", identifier.c_str(), stream_file_name.c_str(), line_number);
		return false;
	}
	if (properties.GetNumProperties() == 0)
		return true;

	StringList rule_list;
	StringUtilities::ExpandString(rule_list, rules);

	Vector<float> rule_values;
	rule_values.reserve(rule_list.size());

	for (auto rule : rule_list)
	{
		float value = 0.0f;
		int count = 0;
		rule = StringUtilities::ToLower(rule);
		if (rule == "from")
			rule_values.push_back(0.0f);
		else if (rule == "to")
			rule_values.push_back(1.0f);
		else if(sscanf(rule.c_str(), "%f%%%n", &value, &count) == 1)
			if(count > 0 && value >= 0.0f && value <= 100.0f)
				rule_values.push_back(0.01f * value);
	}

	if (rule_values.empty())
	{
		Log::Message(Log::LT_WARNING, "Invalid keyframes rule(s) '%s' at %s:%d", rules.c_str(), stream_file_name.c_str(), line_number);
		return false;
	}

	Keyframes& keyframes = keyframes_map[identifier];

	for(float selector : rule_values)
	{
		auto it = std::find_if(keyframes.blocks.begin(), keyframes.blocks.end(), [selector](const KeyframeBlock& keyframe_block) { return Math::AbsoluteValue(keyframe_block.normalized_time - selector) < 0.0001f; });
		if (it == keyframes.blocks.end())
		{
			keyframes.blocks.emplace_back(selector);
			it = (keyframes.blocks.end() - 1);
		}
		else
		{
			// In case of duplicate keyframes, we only use the latest definition as per CSS rules
			it->properties = PropertyDictionary();
		}

		it->properties.Import(properties);
	}

	return true;
}

int StyleSheetParser::Parse(StyleSheetNode* node, Stream* _stream, const StyleSheet& style_sheet, KeyframesMap& keyframes, int begin_line_number)
{
	int rule_count = 0;
	line_number = begin_line_number;
	stream = _stream;
	stream_file_name = StringUtilities::Replace(stream->GetSourceURL().GetURL(), '|', ':');

	enum class State { Global, AtRuleIdentifier, KeyframeBlock, Invalid };
	State state = State::Global;

	// At-rules given by the following syntax in global space: @identifier name { block }
	String at_rule_name;

	// Look for more styles while data is available
	while (FillBuffer())
	{
		String pre_token_str;
		
		while (char token = FindToken(pre_token_str, "{@}", true))
		{
			switch (state)
			{
			case State::Global:
			{
				if (token == '{')
				{
					const int rule_line_number = (int)line_number;
					
					// Read the attributes
					PropertyDictionary properties;
					PropertySpecificationParser parser(properties, StyleSheetSpecification::GetPropertySpecification());
					if (!ReadProperties(parser))
						continue;

					StringList rule_name_list;
					StringUtilities::ExpandString(rule_name_list, pre_token_str);

					// Add style nodes to the root of the tree
					for (size_t i = 0; i < rule_name_list.size(); i++)
					{
						auto source = MakeShared<PropertySource>(stream_file_name, rule_line_number, rule_name_list[i]);
						properties.SetSourceOfAllProperties(source);
						ImportProperties(node, rule_name_list[i], properties, rule_count);
					}

					rule_count++;
				}
				else if (token == '@')
				{
					state = State::AtRuleIdentifier;
				}
				else
				{
					Log::Message(Log::LT_WARNING, "Invalid character '%c' found while parsing stylesheet at %s:%d. Trying to proceed.", token, stream_file_name.c_str(), line_number);
				}
			}
			break;
			case State::AtRuleIdentifier:
			{
				if (token == '{')
				{
					String at_rule_identifier = pre_token_str.substr(0, pre_token_str.find(' '));
					at_rule_name = StringUtilities::StripWhitespace(pre_token_str.substr(at_rule_identifier.size()));

					if (at_rule_identifier == "keyframes")
					{
						state = State::KeyframeBlock;
					}
					else
					{
						// Invalid identifier, should ignore
						at_rule_name.clear();
						state = State::Global;
						Log::Message(Log::LT_WARNING, "Invalid at-rule identifier '%s' found in stylesheet at %s:%d", at_rule_identifier.c_str(), stream_file_name.c_str(), line_number);
					}

				}
				else
				{
					Log::Message(Log::LT_WARNING, "Invalid character '%c' found while parsing at-rule identifier in stylesheet at %s:%d", token, stream_file_name.c_str(), line_number);
					state = State::Invalid;
				}
			}
			break;
			case State::KeyframeBlock:
			{
				if (token == '{')
				{
					// Each keyframe in keyframes has its own block which is processed here
					PropertyDictionary properties;
					PropertySpecificationParser parser(properties, StyleSheetSpecification::GetPropertySpecification());
					if(!ReadProperties(parser))
						continue;

					if (!ParseKeyframeBlock(keyframes, at_rule_name, pre_token_str, properties))
						continue;
				}
				else if (token == '}')
				{
					at_rule_name.clear();
					state = State::Global;
				}
				else
				{
					Log::Message(Log::LT_WARNING, "Invalid character '%c' found while parsing keyframe block in stylesheet at %s:%d", token, stream_file_name.c_str(), line_number);
					state = State::Invalid;
				}
			}
			break;
			default:
				RMLUI_ERROR;
				state = State::Invalid;
				break;
			}

			if (state == State::Invalid)
				break;
		}

		if (state == State::Invalid)
			break;
	}	

	PostprocessKeyframes(keyframes);

	return rule_count;
}

bool StyleSheetParser::ParseProperties(PropertyDictionary& parsed_properties, const String& properties)
{
	RMLUI_ASSERT(!stream);
	StreamMemory stream_owner((const byte*)properties.c_str(), properties.size());
	stream = &stream_owner;
	PropertySpecificationParser parser(parsed_properties, StyleSheetSpecification::GetPropertySpecification());
	bool success = ReadProperties(parser);
	stream = nullptr;
	return success;
}

StyleSheetNodeListRaw StyleSheetParser::ConstructNodes(StyleSheetNode& root_node, const String& selectors)
{
	const PropertyDictionary empty_properties;

	StringList selector_list;
	StringUtilities::ExpandString(selector_list, selectors);

	StyleSheetNodeListRaw leaf_nodes;

	for (const String& selector : selector_list)
	{
		StyleSheetNode* leaf_node = ImportProperties(&root_node, selector, empty_properties, 0);

		if (leaf_node != &root_node)
			leaf_nodes.push_back(leaf_node);
	}

	return leaf_nodes;
}

bool StyleSheetParser::ReadProperties(AbstractPropertyParser& property_parser)
{
	String name;
	String value;

	enum ParseState { NAME, VALUE, QUOTE };
	ParseState state = NAME;

	char character;
	char previous_character = 0;
	while (ReadCharacter(character))
	{
		parse_buffer_pos++;

		switch (state)
		{
			case NAME:
			{
				if (character == ';')
				{
					name = StringUtilities::StripWhitespace(name);
					if (!name.empty())
					{
						Log::Message(Log::LT_WARNING, "Found name with no value while parsing property declaration '%s' at %s:%d", name.c_str(), stream_file_name.c_str(), line_number);
						name.clear();
					}
				}
				else if (character == '}')
				{
					name = StringUtilities::StripWhitespace(name);
					if (!name.empty())
						Log::Message(Log::LT_WARNING, "End of rule encountered while parsing property declaration '%s' at %s:%d", name.c_str(), stream_file_name.c_str(), line_number);
					return true;
				}
				else if (character == ':')
				{
					name = StringUtilities::StripWhitespace(name);
					state = VALUE;
				}
				else
					name += character;
			}
			break;
			
			case VALUE:
			{
				if (character == ';')
				{
					value = StringUtilities::StripWhitespace(value);

					if (!property_parser.Parse(name, value))
						Log::Message(Log::LT_WARNING, "Syntax error parsing property declaration '%s: %s;' in %s: %d.", name.c_str(), value.c_str(), stream_file_name.c_str(), line_number);

					name.clear();
					value.clear();
					state = NAME;
				}
				else if (character == '}')
				{
					break;
				}
				else
				{
					value += character;
					if (character == '"')
						state = QUOTE;
				}
			}
			break;

			case QUOTE:
			{
				value += character;
				if (character == '"' && previous_character != '/')
					state = VALUE;
			}
			break;
		}

		if (character == '}')
			break;
		previous_character = character;
	}

	if (state == VALUE && !name.empty() && !value.empty())
	{
		value = StringUtilities::StripWhitespace(value);

		if (!property_parser.Parse(name, value))
			Log::Message(Log::LT_WARNING, "Syntax error parsing property declaration '%s: %s;' in %s: %d.", name.c_str(), value.c_str(), stream_file_name.c_str(), line_number);
	}
	else if (!name.empty() || !value.empty())
	{
		Log::Message(Log::LT_WARNING, "Invalid property declaration '%s':'%s' at %s:%d", name.c_str(), value.c_str(), stream_file_name.c_str(), line_number);
	}
	
	return true;
}

StyleSheetNode* StyleSheetParser::ImportProperties(StyleSheetNode* node, String rule_name, const PropertyDictionary& properties, int rule_specificity)
{
	StyleSheetNode* leaf_node = node;

	StringList nodes;

	// Find child combinators, the RCSS '>' rule.
	size_t i_child = rule_name.find('>');
	while (i_child != String::npos)
	{
		// So we found one! Next, we want to format the rule such that the '>' is located at the 
		// end of the left-hand-side node, and that there is a space to the right-hand-side. This ensures that
		// the selector is applied to the "parent", and that parent and child are expanded properly below.
		size_t i_begin = i_child;
		while (i_begin > 0 && rule_name[i_begin - 1] == ' ')
			i_begin--;

		const size_t i_end = i_child + 1;
		rule_name.replace(i_begin, i_end - i_begin, "> ");
		i_child = rule_name.find('>', i_begin + 1);
	}

	// Expand each individual node separated by spaces. Don't expand inside parenthesis because of structural selectors.
	StringUtilities::ExpandString(nodes, rule_name, ' ', '(', ')', true);

	// Create each node going down the tree
	for (size_t i = 0; i < nodes.size(); i++)
	{
		const String& name = nodes[i];

		String tag;
		String id;
		StringList classes;
		StringList pseudo_classes;
		StructuralSelectorList structural_pseudo_classes;
		bool child_combinator = false;

		size_t index = 0;
		while (index < name.size())
		{
			size_t start_index = index;
			size_t end_index = index + 1;

			// Read until we hit the next identifier.
			while (end_index < name.size() &&
				   name[end_index] != '#' &&
				   name[end_index] != '.' &&
				   name[end_index] != ':' &&
				   name[end_index] != '>')
				end_index++;

			String identifier = name.substr(start_index, end_index - start_index);
			if (!identifier.empty())
			{
				switch (identifier[0])
				{
					case '#':	id = identifier.substr(1); break;
					case '.':	classes.push_back(identifier.substr(1)); break;
					case ':':
					{
						String pseudo_class_name = identifier.substr(1);
						StructuralSelector node_selector = StyleSheetFactory::GetSelector(pseudo_class_name);
						if (node_selector.selector)
							structural_pseudo_classes.push_back(node_selector);
						else
							pseudo_classes.push_back(pseudo_class_name);
					}
					break;
					case '>':	child_combinator = true; break;

					default:	if(identifier != "*") tag = identifier;
				}
			}

			index = end_index;
		}

		// Sort the classes and pseudo-classes so they are consistent across equivalent declarations that shuffle the order around.
		std::sort(classes.begin(), classes.end());
		std::sort(pseudo_classes.begin(), pseudo_classes.end());
		std::sort(structural_pseudo_classes.begin(), structural_pseudo_classes.end());

		// Get the named child node.
		leaf_node = leaf_node->GetOrCreateChildNode(std::move(tag), std::move(id), std::move(classes), std::move(pseudo_classes), std::move(structural_pseudo_classes), child_combinator);
	}

	// Merge the new properties with those already on the leaf node.
	leaf_node->ImportProperties(properties, rule_specificity);

	return leaf_node;
}

char StyleSheetParser::FindToken(String& buffer, const char* tokens, bool remove_token)
{
	buffer.clear();
	char character;
	while (ReadCharacter(character))
	{
		if (strchr(tokens, character) != nullptr)
		{
			if (remove_token)
				parse_buffer_pos++;
			return character;
		}
		else
		{
			buffer += character;
			parse_buffer_pos++;
		}
	}

	return 0;
}

// Attempts to find the next character in the active stream.
bool StyleSheetParser::ReadCharacter(char& buffer)
{
	bool comment = false;

	// Continuously fill the buffer until either we run out of
	// stream or we find the requested token
	do
	{
		while (parse_buffer_pos < parse_buffer.size())
		{
			if (parse_buffer[parse_buffer_pos] == '\n')
				line_number++;
			else if (comment)
			{
				// Check for closing comment
				if (parse_buffer[parse_buffer_pos] == '*')
				{
					parse_buffer_pos++;
					if (parse_buffer_pos >= parse_buffer.size())
					{
						if (!FillBuffer())
							return false;
					}

					if (parse_buffer[parse_buffer_pos] == '/')
						comment = false;
				}
			}
			else
			{
				// Check for an opening comment
				if (parse_buffer[parse_buffer_pos] == '/')
				{
					parse_buffer_pos++;
					if (parse_buffer_pos >= parse_buffer.size())
					{
						if (!FillBuffer())
						{
							buffer = '/';
							parse_buffer = "/";
							return true;
						}
					}
					
					if (parse_buffer[parse_buffer_pos] == '*')
						comment = true;
					else
					{
						buffer = '/';
						if (parse_buffer_pos == 0)
							parse_buffer.insert(parse_buffer_pos, 1, '/');
						else
							parse_buffer_pos--;
						return true;
					}
				}

				if (!comment)
				{
					// If we find a character, return it
					buffer = parse_buffer[parse_buffer_pos];
					return true;
				}
			}

			parse_buffer_pos++;
		}
	}
	while (FillBuffer());

	return false;
}

// Fills the internal buffer with more content
bool StyleSheetParser::FillBuffer()
{
	// If theres no data to process, abort
	if (stream->IsEOS())
		return false;

	// Read in some data (4092 instead of 4096 to avoid the buffer growing when we have to add back
	// a character after a failed comment parse.)
	parse_buffer.clear();
	bool read = stream->Read(parse_buffer, 4092) > 0;
	parse_buffer_pos = 0;

	return read;
}

} // namespace Rml
