#include <css/StyleSheetFactory.h>
#include <css/StyleSheet.h>
#include <core/Interface.h>
#include <binding/Context.h>
#include <util/Log.h>
#include <css/StyleSheetNode.h>
#include <css/StyleSheetNodeSelector.h>
#include <css/StyleSheetParser.h>

namespace Rml {

class StyleSheetFactoryInstance {
public:
	bool LoadStyleSheet(StyleSheet& sheet, std::string_view source_path);
	void LoadStyleSheet(StyleSheet& sheet, std::string_view source_path, std::string_view content);
	void LoadStyleSheet(StyleSheet& sheet, std::string_view source_path, std::string_view content, int line);
	std::unordered_map<std::string_view, StyleSheet> stylesheets;
};

bool StyleSheetFactoryInstance::LoadStyleSheet(StyleSheet& sheet, std::string_view source_path) {
	auto itr = stylesheets.find(source_path);
	if (itr != stylesheets.end()) {
		sheet.Merge(itr->second);
		return true;
	}
	return false;
}

void StyleSheetFactoryInstance::LoadStyleSheet(StyleSheet& sheet, std::string_view source_path, std::string_view content) {
	auto& newsheet = stylesheets[source_path];
	StyleSheetParser parser;
	if (!parser.Parse(content, newsheet, source_path, 1)) {
		Log::Message(Log::Level::Error, "Failed to load style sheet in %s.", source_path.data());
		return;
	}
	sheet.Merge(newsheet);
}

void StyleSheetFactoryInstance::LoadStyleSheet(StyleSheet& sheet, std::string_view source_path, std::string_view content, int line) {
	StyleSheetParser parser;
	if (!parser.Parse(content, sheet, source_path, line)) {
		Log::Message(Log::Level::Error, "Failed to load style sheet in %s:%d.", source_path.data(), line);
	}
}

static StyleSheetFactoryInstance* instance = nullptr;

void StyleSheetFactory::Initialise() {
	if (!instance) {
		instance = new StyleSheetFactoryInstance();
	}
}

void StyleSheetFactory::Shutdown() {
	if (instance) {
		delete instance;
	}
}

bool StyleSheetFactory::CombineStyleSheet(StyleSheet& sheet, std::string_view source_path) {
	return instance->LoadStyleSheet(sheet, source_path);
}

void StyleSheetFactory::CombineStyleSheet(StyleSheet& sheet, std::string_view source_path, std::string_view content) {
	instance->LoadStyleSheet(sheet, source_path, content);
}

void StyleSheetFactory::CombineStyleSheet(StyleSheet& sheet, std::string_view source_path, std::string_view content, int line) {
	instance->LoadStyleSheet(sheet, source_path, content, line);
}

}
