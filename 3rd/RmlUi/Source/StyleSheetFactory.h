#pragma once

#include "../Include/RmlUi/Types.h"

namespace Rml {

class StyleSheet;
struct StyleSheetNodeSelector;
struct StructuralSelector;

class StyleSheetFactory {
public:
	static void Initialise();
	static void Shutdown();
	static void CombineStyleSheet(StyleSheet& sheet, const std::string& source_path);
	static void CombineStyleSheet(StyleSheet& sheet, const std::string& content, const std::string& source_path, int line);
	static StructuralSelector GetSelector(const std::string& name);
};

}
