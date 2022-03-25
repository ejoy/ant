#include "StyleSheetFactory.h"
#include "../Include/RmlUi/StyleSheet.h"
#include "../Include/RmlUi/StringUtilities.h"
#include "../Include/RmlUi/Stream.h"
#include "../Include/RmlUi/Log.h"
#include "StyleSheetNode.h"
#include "StyleSheetNodeSelector.h"

namespace Rml {

static void Combine(StyleSheet& sheet, std::shared_ptr<StyleSheet> subsheet) {
	if (subsheet) {
		sheet.CombineStyleSheet(*subsheet);
	}
}

class StyleSheetFactoryInstance {
public:
	~StyleSheetFactoryInstance();
	std::shared_ptr<StyleSheet> LoadStyleSheet(const std::string& source_path);
	std::shared_ptr<StyleSheet> LoadStyleSheet(const std::string& content, const std::string& source_path, int line);
	StructuralSelector GetSelector(const std::string& name);

	std::unordered_map<std::string, StyleSheetNodeSelector*> selectors = {
		{ "nth-child", new StyleSheetNodeSelectorNthChild() },
		{ "nth-last-child", new StyleSheetNodeSelectorNthLastChild() },
		{ "nth-of-type", new StyleSheetNodeSelectorNthOfType() },
		{ "nth-last-of-type", new StyleSheetNodeSelectorNthLastOfType() },
		{ "first-child", new StyleSheetNodeSelectorFirstChild() },
		{ "last-child", new StyleSheetNodeSelectorLastChild() },
		{ "first-of-type", new StyleSheetNodeSelectorFirstOfType() },
		{ "last-of-type", new StyleSheetNodeSelectorLastOfType() },
		{ "only-child", new StyleSheetNodeSelectorOnlyChild() },
		{ "only-of-type", new StyleSheetNodeSelectorOnlyOfType() },
		{ "empty", new StyleSheetNodeSelectorEmpty() },
	};
	std::unordered_map<std::string, std::shared_ptr<StyleSheet>> stylesheets;
};

StyleSheetFactoryInstance::~StyleSheetFactoryInstance() {
	for (auto [_, selector] : selectors) {
		delete selector;
	}
}

std::shared_ptr<StyleSheet> StyleSheetFactoryInstance::LoadStyleSheet(const std::string& source_path) {
	auto itr = stylesheets.find(source_path);
	if (itr != stylesheets.end()) {
		return (*itr).second;
	}
	Stream stream(source_path);
	std::shared_ptr<StyleSheet> sheet = std::make_shared<StyleSheet>();
	if (!sheet->LoadStyleSheet(&stream)) {
		return nullptr;
	}
	stylesheets.emplace(source_path, sheet);
	return sheet;
}

std::shared_ptr<StyleSheet> StyleSheetFactoryInstance::LoadStyleSheet(const std::string& content, const std::string& source_path, int line) {
	Stream stream(source_path, (const uint8_t*)content.data(), content.size());
	std::shared_ptr<StyleSheet> sheet = std::make_shared<StyleSheet>();
	if (!sheet->LoadStyleSheet(&stream, line)) {
		return nullptr;
	}
	return sheet;
}

StructuralSelector StyleSheetFactoryInstance::GetSelector(const std::string& name) {
	const size_t parameter_start = name.find('(');
	auto it = (parameter_start == std::string::npos)
			? selectors.find(name)
			: selectors.find(name.substr(0, parameter_start))
			;
	if (it == selectors.end())
		return StructuralSelector(nullptr, 0, 0);

	// Parse the 'a' and 'b' values.
	int a = 1;
	int b = 0;

	const size_t parameter_end = name.find(')', parameter_start + 1);
	if (parameter_start != std::string::npos &&
		parameter_end != std::string::npos)
	{
		std::string parameters = StringUtilities::StripWhitespace(name.substr(parameter_start + 1, parameter_end - (parameter_start + 1)));

		// Check for 'even' or 'odd' first.
		if (parameters == "even")
		{
			a = 2;
			b = 0;
		}
		else if (parameters == "odd")
		{
			a = 2;
			b = 1;
		}
		else
		{
			// Alrighty; we've got an equation in the form of [[+/-]an][(+/-)b]. So, foist up, we split on 'n'.
			const size_t n_index = parameters.find('n');
			if (n_index == std::string::npos)
			{
				// The equation is 0n + b. So a = 0, and we only have to parse b.
				a = 0;
				b = atoi(parameters.c_str());
			}
			else
			{
				if (n_index == 0)
					a = 1;
				else
				{
					const std::string a_parameter = parameters.substr(0, n_index);
					if (StringUtilities::StripWhitespace(a_parameter) == "-")
						a = -1;
					else
						a = atoi(a_parameter.c_str());
				}

				size_t pm_index = parameters.find('+', n_index + 1);
				if (pm_index != std::string::npos)
					b = 1;
				else
				{
					pm_index = parameters.find('-', n_index + 1);
					if (pm_index != std::string::npos)
						b = -1;
				}

				if (n_index == parameters.size() - 1 || pm_index == std::string::npos)
					b = 0;
				else
					b = b * atoi(parameters.data() + pm_index + 1);
			}
		}
	}

	return StructuralSelector(it->second, a, b);
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
	Combine(sheet, instance->LoadStyleSheet(source_path));
}

void StyleSheetFactory::CombineStyleSheet(StyleSheet& sheet, const std::string& content, const std::string& source_path, int line) {
	Combine(sheet, instance->LoadStyleSheet(content, source_path, line));
}

StructuralSelector StyleSheetFactory::GetSelector(const std::string& name) {
	return instance->GetSelector(name);
}

}
