#include <css/StyleSheetParser.h>
#include <css/StyleSheetNode.h>
#include <util/Log.h>
#include <css/StyleSheet.h>
#include <css/StyleSheetSpecification.h>
#include <util/StringUtilities.h>
#include <algorithm>
#include <assert.h>
#include <string.h>

namespace Rml {

class StyleSheetParser {
public:
	bool Parse(std::string_view data, StyleSheet& style_sheet, std::string_view source_url, int begin_line_number);
	bool ParseProperties(std::string_view data, PropertyVector& vec);

private:
	std::string_view view;
	size_t           pos;
	std::string_view source_url;
	size_t           line_number;

	bool ReadProperties(PropertyVector& vec);
	bool ParseKeyframeBlock(StyleSheet& style_sheet, const std::string & identifier, const std::string & rules, const PropertyVector& properties);
	char FindToken(std::string& buffer, const char* tokens, bool remove_token);
	bool ReadCharacter(char& buffer);

	uint8_t Peek() const;
	bool End() const;
	void Next();
	void Undo();
};

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
					Style::TableRef style_properties = Style::Instance().Create(properties);
					std::vector<std::string> rule_name_list;
					StringUtilities::ExpandString(rule_name_list, pre_token_str, ',');
					for (size_t i = 0; i < rule_name_list.size(); i++) {
						StyleSheetNode node(rule_name_list[i], style_properties);
						style_sheet.AddNode(std::move(node));
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

					if (!StyleSheetSpecification::ParseDeclaration(vec, name, value))
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
					if (character == '"' || character == '\'')
						state = QUOTE;
				}
			}
			break;

			case QUOTE:
			{
				value += character;
				if ((character == '"' || character == '\'') && previous_character != '/')
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

		if (!StyleSheetSpecification::ParseDeclaration(vec, name, value))
			Log::Message(Log::Level::Warning, "Syntax error parsing property declaration '%s: %s;' in %s: %d.", name.c_str(), value.c_str(), source_url.data(), line_number);
	}
	else if (!name.empty() || !value.empty())
	{
		Log::Message(Log::Level::Warning, "Invalid property declaration '%s':'%s' at %s:%d", name.c_str(), value.c_str(), source_url.data(), line_number);
	}
	
	return true;
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

void ParseStyleSheet(PropertyVector& properties, std::string_view data) {
	StyleSheetParser parser;
	parser.ParseProperties(data, properties);
}

void ParseStyleSheet(StyleSheet& sheet, std::string_view source_path, std::string_view content) {
	StyleSheetParser parser;
	if (!parser.Parse(content, sheet, source_path, 1)) {
		Log::Message(Log::Level::Error, "Failed to load style sheet in %s.", source_path.data());
		return;
	}
}

void ParseStyleSheet(StyleSheet& sheet, std::string_view source_path, std::string_view content, int line) {
	StyleSheetParser parser;
	if (!parser.Parse(content, sheet, source_path, line)) {
		Log::Message(Log::Level::Error, "Failed to load style sheet in %s:%d.", source_path.data(), line);
	}
}

}
