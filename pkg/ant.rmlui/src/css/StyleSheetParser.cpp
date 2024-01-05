#include <css/StyleSheetParser.h>
#include <css/StyleSheetFactory.h>
#include <css/StyleSheetNode.h>
#include <util/Log.h>
#include <css/StyleSheet.h>
#include <css/StyleSheetSpecification.h>
#include <util/StringUtilities.h>
#include <algorithm>
#include <assert.h>
#include <string.h>

namespace Rml {

static StructuralSelector GetSelector(const std::string& name) {
	const size_t parameter_start = name.find('(');
	auto func = (parameter_start == std::string::npos)
			? CreateSelector(name)
			: CreateSelector(name.substr(0, parameter_start))
			;
	if (!func)
		return StructuralSelector(nullptr, 0, 0);

	// Parse the 'a' and 'b' values.
	int a = 1;
	int b = 0;

	const size_t parameter_end = name.find(')', parameter_start + 1);
	if (parameter_start != std::string::npos && parameter_end != std::string::npos) {
		std::string parameters = StringUtilities::StripWhitespace(name.substr(parameter_start + 1, parameter_end - (parameter_start + 1)));

		// Check for 'even' or 'odd' first.
		if (parameters == "even") {
			a = 2;
			b = 0;
		}
		else if (parameters == "odd") {
			a = 2;
			b = 1;
		}
		else {
			// Alrighty; we've got an equation in the form of [[+/-]an][(+/-)b]. So, foist up, we split on 'n'.
			const size_t n_index = parameters.find('n');
			if (n_index == std::string::npos) {
				// The equation is 0n + b. So a = 0, and we only have to parse b.
				a = 0;
				b = atoi(parameters.c_str());
			}
			else {
				if (n_index == 0)
					a = 1;
				else {
					const std::string a_parameter = parameters.substr(0, n_index);
					if (StringUtilities::StripWhitespace(a_parameter) == "-")
						a = -1;
					else
						a = atoi(a_parameter.c_str());
				}

				size_t pm_index = parameters.find('+', n_index + 1);
				if (pm_index != std::string::npos)
					b = 1;
				else {
					pm_index = parameters.find('-', n_index + 1);
					if (pm_index != std::string::npos)
						b = -1;
				}

				if (n_index == parameters.size() - 1 || pm_index == std::string::npos)
					b = 0;
				else
					b = b * atoi(parameters.data() + pm_index + 1);
			}
		}
	}

	return StructuralSelector(func, a, b);
}

static bool IsValidIdentifier(const std::string& str) {
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

bool StyleSheetParser::ParseKeyframeBlock(StyleSheet& style_sheet, const std::string& identifier, const std::string& rules, const PropertyVector& properties) {
	if (!IsValidIdentifier(identifier)) {
		Log::Message(Log::Level::Warning, "Invalid keyframes identifier '%s' at %s:%d", identifier.c_str(), source_url.data(), line_number);
		return false;
	}
	if (properties.empty()) {
		return true;
	}

	std::vector<std::string> rule_list;
	StringUtilities::ExpandString(rule_list, rules, ',');

	std::vector<float> rule_values;
	rule_values.reserve(rule_list.size());

	for (auto rule : rule_list) {
		float value = 0.0f;
		int count = 0;
		if (rule == "from")
			rule_values.push_back(0.0f);
		else if (rule == "to")
			rule_values.push_back(1.0f);
		else if(sscanf(rule.c_str(), "%f%%%n", &value, &count) == 1)
			if(count > 0 && value >= 0.0f && value <= 100.0f)
				rule_values.push_back(0.01f * value);
	}

	if (rule_values.empty()) {
		Log::Message(Log::Level::Warning, "Invalid keyframes rule(s) '%s' at %s:%d", rules.c_str(), source_url.data(), line_number);
		return false;
	}

	style_sheet.AddKeyframe(identifier, rule_values, properties);
	return true;
}

bool StyleSheetParser::Parse(std::string_view data, StyleSheet& style_sheet, std::string_view url, int begin_line_number) {
	view = data;
	pos = 0;
	line_number = begin_line_number;
	source_url = url;

	int rule_count = 0;

	enum class State : uint8_t { Global, AtRuleIdentifier, KeyframeBlock, Invalid };
	State state = State::Global;

	// At-rules given by the following syntax in global space: @identifier name { block }
	std::string at_rule_name;

	// Look for more styles while data is available
	do
	{
		std::string pre_token_str;
		
		while (char token = FindToken(pre_token_str, "{@}", true))
		{
			switch (state)
			{
			case State::Global:
			{
				if (token == '{')
				{
					PropertyVector properties;
					if (!ReadProperties(properties))
						continue;

					std::vector<std::string> rule_name_list;
					StringUtilities::ExpandString(rule_name_list, pre_token_str, ',');

					// Add style nodes to the root of the tree
					for (size_t i = 0; i < rule_name_list.size(); i++) {
						ImportProperties(style_sheet, rule_name_list[i], properties);
					}

					rule_count++;
				}
				else if (token == '@')
				{
					state = State::AtRuleIdentifier;
				}
				else
				{
					Log::Message(Log::Level::Warning, "Invalid character '%c' found while parsing stylesheet at %s:%d. Trying to proceed.", token, source_url.data(), line_number);
				}
			}
			break;
			case State::AtRuleIdentifier:
			{
				if (token == '{')
				{
					std::string at_rule_identifier = pre_token_str.substr(0, pre_token_str.find(' '));
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
						Log::Message(Log::Level::Warning, "Invalid at-rule identifier '%s' found in stylesheet at %s:%d", at_rule_identifier.c_str(), source_url.data(), line_number);
					}

				}
				else
				{
					Log::Message(Log::Level::Warning, "Invalid character '%c' found while parsing at-rule identifier in stylesheet at %s:%d", token, source_url.data(), line_number);
					state = State::Invalid;
				}
			}
			break;
			case State::KeyframeBlock:
			{
				if (token == '{')
				{
					// Each keyframe in keyframes has its own block which is processed here
					PropertyVector properties;
					if(!ReadProperties(properties))
						continue;

					if (!ParseKeyframeBlock(style_sheet, at_rule_name, pre_token_str, properties))
						continue;
				}
				else if (token == '}')
				{
					at_rule_name.clear();
					state = State::Global;
				}
				else
				{
					Log::Message(Log::Level::Warning, "Invalid character '%c' found while parsing keyframe block in stylesheet at %s:%d", token, source_url.data(), line_number);
					state = State::Invalid;
				}
			}
			break;
			default:
				assert(false);
				state = State::Invalid;
				break;
			}

			if (state == State::Invalid)
				break;
		}

		if (state == State::Invalid)
			break;
	}
	while(false);

	return rule_count >= 0;
}

bool StyleSheetParser::ParseProperties(std::string_view data, PropertyVector& vec) {
	view = data;
	pos = 0;
	line_number = 0;
	source_url = "";
	return ReadProperties(vec);
}

bool StyleSheetParser::ReadProperties(PropertyVector& vec)
{
	std::string name;
	std::string value;

	enum ParseState { NAME, VALUE, QUOTE };
	ParseState state = NAME;

	char character;
	char previous_character = 0;
	while (ReadCharacter(character))
	{
		Next();

		switch (state)
		{
			case NAME:
			{
				if (character == ';')
				{
					name = StringUtilities::StripWhitespace(name);
					if (!name.empty())
					{
						Log::Message(Log::Level::Warning, "Found name with no value while parsing property declaration '%s' at %s:%d", name.c_str(), source_url.data(), line_number);
						name.clear();
					}
				}
				else if (character == '}')
				{
					name = StringUtilities::StripWhitespace(name);
					if (!name.empty())
						Log::Message(Log::Level::Warning, "End of rule encountered while parsing property declaration '%s' at %s:%d", name.c_str(), source_url.data(), line_number);
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

					if (!StyleSheetSpecification::ParsePropertyDeclaration(vec, name, value))
						Log::Message(Log::Level::Warning, "Syntax error parsing property declaration '%s: %s;' in %s: %d.", name.c_str(), value.c_str(), source_url.data(), line_number);

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

		if (!StyleSheetSpecification::ParsePropertyDeclaration(vec, name, value))
			Log::Message(Log::Level::Warning, "Syntax error parsing property declaration '%s: %s;' in %s: %d.", name.c_str(), value.c_str(), source_url.data(), line_number);
	}
	else if (!name.empty() || !value.empty())
	{
		Log::Message(Log::Level::Warning, "Invalid property declaration '%s':'%s' at %s:%d", name.c_str(), value.c_str(), source_url.data(), line_number);
	}
	
	return true;
}

void StyleSheetParser::ImportProperties(StyleSheet& style_sheet, std::string rule_name, const PropertyVector& properties)
{
	StyleSheetNode node;
	std::vector<std::string> nodes;

	// Find child combinators, the RCSS '>' rule.
	size_t i_child = rule_name.find('>');
	while (i_child != std::string::npos)
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
	StringUtilities::ExpandString2(nodes, rule_name, ' ', '(', ')', true);

	// Create each node going down the tree
	for (size_t i = 0; i < nodes.size(); i++)
	{
		const std::string& name = nodes[i];
		
		StyleSheetRequirements requirements;
		std::vector<std::string> pseudo_classes;

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

			std::string identifier = name.substr(start_index, end_index - start_index);
			if (!identifier.empty())
			{
				switch (identifier[0])
				{
					case '#':	requirements.id = identifier.substr(1); break;
					case '.':	requirements.class_names.push_back(identifier.substr(1)); break;
					case ':':
					{
						std::string pseudo_class_name = identifier.substr(1);
						StructuralSelector node_selector = GetSelector(pseudo_class_name);
						if (node_selector.selector)
							requirements.structural_selectors.push_back(node_selector);
						else
							pseudo_classes.push_back(pseudo_class_name);
					}
					break;
					case '>':	requirements.child_combinator = true; break;

					default:	if(identifier != "*") requirements.tag = identifier;
				}
			}

			index = end_index;
		}

		std::sort(requirements.class_names.begin(), requirements.class_names.end());
		std::sort(requirements.structural_selectors.begin(), requirements.structural_selectors.end());

		PseudoClassSet set = 0;
		for (auto& name : pseudo_classes) {
			if (name == "active") {
				set = set | PseudoClass::Active;
			}
			else if (name == "hover") {
				set = set | PseudoClass::Hover;
			}
		}
		requirements.pseudo_classes = set;

		// Get the named child node.
		node.AddRequirements(std::move(requirements));
	}

	// Merge the new properties with those already on the leaf node.
	node.SetProperties(properties);
	style_sheet.AddNode(std::move(node));
}

char StyleSheetParser::FindToken(std::string& buffer, const char* tokens, bool remove_token) {
	buffer.clear();
	char character;
	while (ReadCharacter(character)) {
		if (strchr(tokens, character) != nullptr) {
			if (remove_token)
				Next();
			return character;
		}
		else {
			buffer += character;
			Next();
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
		while (!End())
		{
			if (Peek() == '\n')
				line_number++;
			else if (comment)
			{
				// Check for closing comment
				if (Peek() == '*')
				{
					Next();
					if (End())
					{
						return false;
					}

					if (Peek() == '/')
						comment = false;
				}
			}
			else
			{
				// Check for an opening comment
				if (Peek() == '/')
				{
					Next();
					if (End())
					{
						buffer = '/';
						return true;
					}
					
					if (Peek() == '*')
						comment = true;
					else
					{
						buffer = '/';
						Undo();
						return true;
					}
				}

				if (!comment)
				{
					// If we find a character, return it
					buffer = Peek();
					return true;
				}
			}

			Next();
		}
	}
	while (false);

	return false;
}



uint8_t StyleSheetParser::Peek() const {
	return view[pos];
}

bool StyleSheetParser::End() const {
	return pos >= view.size();
}

void StyleSheetParser::Next() {
	pos++;
}

void StyleSheetParser::Undo() {
	pos--;
}

}
