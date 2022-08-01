#pragma once

#include <core/StyleSheet.h>
#include <core/PropertyDictionary.h>

namespace Rml {

class Stream;

class StyleSheetParser {
public:
	StyleSheetParser();
	~StyleSheetParser();

	int Parse(Stream* stream, StyleSheet& style_sheet, KeyframesMap& keyframes, int begin_line_number);
	bool ParseProperties(PropertyVector& vec, const std::string& properties);

private:
	Stream* stream;
	size_t line_number;

	bool ReadProperties(PropertyVector& vec);
	static void ImportProperties(StyleSheet& style_sheet, std::string rule_name, const PropertyVector& properties, int rule_specificity);
	bool ParseKeyframeBlock(KeyframesMap & keyframes_map, const std::string & identifier, const std::string & rules, const PropertyVector& properties);
	char FindToken(std::string& buffer, const char* tokens, bool remove_token);
	bool ReadCharacter(char& buffer);
};

}
