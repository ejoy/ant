#pragma once

#include <css/StyleSheetNodeSelector.h>
#include <string_view>

namespace Rml {

class StyleSheet;

class StyleSheetFactory {
public:
	static void Initialise();
	static void Shutdown();
	static bool CombineStyleSheet(StyleSheet& sheet, std::string_view source_path);
	static void CombineStyleSheet(StyleSheet& sheet, std::string_view source_path, std::string_view content);
	static void CombineStyleSheet(StyleSheet& sheet, std::string_view source_path, std::string_view content, int line);
};

}
