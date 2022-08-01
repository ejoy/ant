#include <core/StyleSheet.h>
#include <core/StyleSheetFactory.h>
#include <core/StyleSheetNode.h>
#include <core/StyleSheetParser.h>
#include <core/Element.h>
#include <core/StyleSheetSpecification.h>
#include <core/Property.h>
#include <core/Log.h>
#include <core/Stream.h>
#include <algorithm>
#include <array>

namespace Rml {

inline static bool StyleSheetNodeSort(const StyleSheetNode* lhs, const StyleSheetNode* rhs) {
	return lhs->GetSpecificity() < rhs->GetSpecificity();
}

StyleSheet::StyleSheet() {
	root = std::make_unique<StyleSheetNode>();
	specificity_offset = 0;
}

StyleSheet::~StyleSheet()
{}

bool StyleSheet::LoadStyleSheet(Stream* stream, int begin_line_number) {
	StyleSheetParser parser;
	specificity_offset = parser.Parse(root.get(), stream, *this, keyframes, begin_line_number);
	bool ok = specificity_offset >= 0;
	if (!ok) {
		Log::Message(Log::Level::Error, "Failed to load style sheet in %s.", stream->GetSourceURL().c_str());
	}
	return ok;
}

void StyleSheet::CombineStyleSheet(const StyleSheet& other_sheet) {
	root->MergeHierarchy(other_sheet.root.get(), specificity_offset);

	keyframes.reserve(keyframes.size() + other_sheet.keyframes.size());
	for (auto& other_keyframes : other_sheet.keyframes)
	{
		keyframes[other_keyframes.first] = other_keyframes.second;
	}

	specificity_offset += other_sheet.specificity_offset;
}

void StyleSheet::BuildNodeIndex() {
	styled_node_index.clear();
	root->BuildIndex(styled_node_index);
}

const Keyframes* StyleSheet::GetKeyframes(const std::string & name) const {
	auto it = keyframes.find(name);
	if (it != keyframes.end())
		return &(it->second);
	return nullptr;
}

SharedPtr<StyleSheetPropertyDictionary> StyleSheet::GetElementDefinition(const Element* element) const {
	static std::vector<const StyleSheetNode*> applicable_nodes;
	applicable_nodes.clear();
	for (StyleSheetNode* node : styled_node_index) {
		if (node->IsApplicable(element)) {
			applicable_nodes.push_back(node);
		}
	}
	std::sort(applicable_nodes.begin(), applicable_nodes.end(), StyleSheetNodeSort);
	if (applicable_nodes.empty())
		return nullptr;
	auto new_definition = MakeShared<StyleSheetPropertyDictionary>();
	for (auto const& node : applicable_nodes) {
		node->MergeProperties(*new_definition);
	}
	return new_definition;
}

}
