#pragma once

#include <string>
#include <core/StyleSheetNodeSelector.h>

namespace Rml {

class StyleSheet;

class StyleSheetFactory {
public:
	static void Initialise();
	static void Shutdown();
	static void CombineStyleSheet(StyleSheet& sheet, const std::string& source_path);
	static void CombineStyleSheet(StyleSheet& sheet, const std::string& content, const std::string& source_path, int line);
	static Selector::IsApplicable GetSelector(const std::string& name);
};

}
