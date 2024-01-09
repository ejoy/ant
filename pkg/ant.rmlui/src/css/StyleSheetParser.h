#pragma once

#include <css/StyleSheet.h>
#include <css/Property.h>

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

}
