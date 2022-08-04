#include <core/StyleSheetFactory.h>
#include <core/StyleSheet.h>
#include <core/StringUtilities.h>
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
	StructuralSelector GetSelector(const std::string& name);

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
	instance->LoadStyleSheet(sheet, source_path);
}

void StyleSheetFactory::CombineStyleSheet(StyleSheet& sheet, const std::string& content, const std::string& source_path, int line) {
	instance->LoadStyleSheet(sheet, content, source_path, line);
}

StructuralSelector StyleSheetFactory::GetSelector(const std::string& name) {
	return instance->GetSelector(name);
}

}
