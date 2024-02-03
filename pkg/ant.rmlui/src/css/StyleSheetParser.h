#pragma once

#include <css/Property.h>

namespace Rml {

class StyleSheet;

void ParseStyleSheet(PropertyVector& properties, std::string_view data);
void ParseStyleSheet(StyleSheet& sheet, std::string_view source_path, std::string_view content);
void ParseStyleSheet(StyleSheet& sheet, std::string_view source_path, std::string_view content, int line);

}
