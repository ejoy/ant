#pragma once

#include <string>
#include <css/StyleSheetNodeSelector.h>

namespace Rml {

class StyleSheet;

class StyleSheetFactory {
public:
	static void Initialise();
	static void Shutdown();
	static bool CombineStyleSheet(StyleSheet& sheet, std::string_view source_path);
	static void CombineStyleSheet(StyleSheet& sheet, std::string_view source_path, std::string_view content);
	static void CombineStyleSheet(StyleSheet& sheet, std::string_view source_path, std::string_view content, int line);
	static Selector::IsApplicable GetSelector(const std::string& name);
};

}
