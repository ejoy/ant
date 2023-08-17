#include <css/StyleSheetFactory.h>
#include <css/StyleSheet.h>
#include <core/Interface.h>
#include <core/Core.h>
#include <util/Stream.h>
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
	Selector::IsApplicable GetSelector(const std::string& name);

	std::unordered_map<std::string, Selector::IsApplicable> selectors = {
		{ "nth-child", Selector::NthChild },
		{ "nth-last-child", Selector::NthLastChild },
		{ "nth-of-type", Selector::NthOfType },
		{ "nth-last-of-type", Selector::NthLastOfType },
		{ "first-child", Selector::FirstChild },
		{ "last-child", Selector::LastChild },
		{ "first-of-type", Selector::FirstOfType },
		{ "last-of-type", Selector::LastOfType },
		{ "only-child", Selector::OnlyChild },
		{ "only-of-type", Selector::OnlyOfType },
		{ "empty", Selector::Empty },
	};
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
	Stream stream(content);
	if (!parser.Parse(stream, newsheet, source_path, 1)) {
		Log::Message(Log::Level::Error, "Failed to load style sheet in %s.", source_path.data());
		return;
	}
	sheet.Merge(newsheet);
}

void StyleSheetFactoryInstance::LoadStyleSheet(StyleSheet& sheet, std::string_view source_path, std::string_view content, int line) {
	StyleSheetParser parser;
	Stream stream(content);
	if (!parser.Parse(stream, sheet, source_path, line)) {
		Log::Message(Log::Level::Error, "Failed to load style sheet in %s:%d.", source_path.data(), line);
	}
}

Selector::IsApplicable StyleSheetFactoryInstance::GetSelector(const std::string& name) {
	auto it = selectors.find(name);
	if (it == selectors.end())
		return nullptr;
	return it->second;
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

Selector::IsApplicable StyleSheetFactory::GetSelector(const std::string& name) {
	return instance->GetSelector(name);
}

}
