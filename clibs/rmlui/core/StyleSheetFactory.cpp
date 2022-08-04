#include <core/StyleSheetFactory.h>
#include <core/StyleSheet.h>
#include <core/Stream.h>
#include <core/Log.h>
#include <core/StyleSheetNode.h>
#include <core/StyleSheetNodeSelector.h>
#include <core/StyleSheetParser.h>

namespace Rml {

class StyleSheetFactoryInstance {
public:
	void LoadStyleSheet(StyleSheet& sheet, const std::string& source_path);
	void LoadStyleSheet(StyleSheet& sheet, const std::string& content, const std::string& source_path, int line);
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
	std::unordered_map<std::string, StyleSheet> stylesheets;
};

void StyleSheetFactoryInstance::LoadStyleSheet(StyleSheet& sheet, const std::string& source_path) {
	auto itr = stylesheets.find(source_path);
	if (itr != stylesheets.end()) {
		sheet.Merge(itr->second);
		return;
	}
	auto& newsheet = stylesheets[source_path];
	StyleSheetParser parser;
	Stream stream(source_path);
	if (!parser.Parse(stream, newsheet, 1)) {
		Log::Message(Log::Level::Error, "Failed to load style sheet in %s.", source_path.c_str());
		return;
	}
	sheet.Merge(newsheet);
}

void StyleSheetFactoryInstance::LoadStyleSheet(StyleSheet& sheet, const std::string& content, const std::string& source_path, int line) {
	StyleSheetParser parser;
	Stream stream(source_path, (const uint8_t*)content.data(), content.size());
	if (!parser.Parse(stream, sheet, line)) {
		Log::Message(Log::Level::Error, "Failed to load style sheet in %s:%d.", source_path.c_str(), line);
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

void StyleSheetFactory::CombineStyleSheet(StyleSheet& sheet, const std::string& source_path) {
	instance->LoadStyleSheet(sheet, source_path);
}

void StyleSheetFactory::CombineStyleSheet(StyleSheet& sheet, const std::string& content, const std::string& source_path, int line) {
	instance->LoadStyleSheet(sheet, content, source_path, line);
}

Selector::IsApplicable StyleSheetFactory::GetSelector(const std::string& name) {
	return instance->GetSelector(name);
}

}
