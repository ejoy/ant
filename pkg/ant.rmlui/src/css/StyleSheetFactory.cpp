#include <css/StyleSheetFactory.h>
#include <css/StyleSheet.h>
#include <core/Interface.h>
#include <core/Core.h>
#include <util/Stream.h>
#include <util/Log.h>
#include <util/File.h>
#include <css/StyleSheetNode.h>
#include <css/StyleSheetNodeSelector.h>
#include <css/StyleSheetParser.h>

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

static std::string_view ReadAll(const std::string& path) {
	auto realpath = GetPlugin()->OnRealPath(path);
	File f(realpath);
	if (!f) {
		Log::Message(Log::Level::Warning, "Unable to open file %s.", path.c_str());
		return {};
	}
	size_t len = f.Length();
	uint8_t* buf = new uint8_t[len];
	len = f.Read(buf, len);
	return {(char*)buf, len};
}

void StyleSheetFactoryInstance::LoadStyleSheet(StyleSheet& sheet, const std::string& source_path) {
	auto itr = stylesheets.find(source_path);
	if (itr != stylesheets.end()) {
		sheet.Merge(itr->second);
		return;
	}
	auto& newsheet = stylesheets[source_path];
	StyleSheetParser parser;
	Stream stream(ReadAll(source_path));
	if (!parser.Parse(stream, newsheet, source_path, 1)) {
		Log::Message(Log::Level::Error, "Failed to load style sheet in %s.", source_path.c_str());
		return;
	}
	sheet.Merge(newsheet);
}

void StyleSheetFactoryInstance::LoadStyleSheet(StyleSheet& sheet, const std::string& content, const std::string& source_path, int line) {
	StyleSheetParser parser;
	Stream stream(content);
	if (!parser.Parse(stream, sheet, source_path, line)) {
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
