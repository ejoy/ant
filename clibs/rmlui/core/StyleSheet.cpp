#include <core/StyleSheet.h>
#include <core/StyleSheetNode.h>
#include <algorithm>

namespace Rml {

StyleSheet::StyleSheet()
{}

StyleSheet::~StyleSheet()
{}

void StyleSheet::Merge(const StyleSheet& other_sheet) {
	stylenode.insert(stylenode.end(), other_sheet.stylenode.begin(), other_sheet.stylenode.end());
	for (auto const& [identifier, values] : other_sheet.keyframes) {
		auto& kf = keyframes[identifier];
		for (auto const& value : values.blocks) {
			kf.blocks.emplace_back(value);
		}
	}
}

const Keyframes* StyleSheet::GetKeyframes(const std::string & name) const {
	auto it = keyframes.find(name);
	if (it != keyframes.end())
		return &(it->second);
	return nullptr;
}

Style::Combination StyleSheet::GetElementDefinition(const Element* element) const {
	std::vector<Style::Value> applicable;
	for (auto& node : stylenode) {
		if (node.IsApplicable(element)) {
			applicable.push_back(node.GetProperties());
		}
	}
	return Style::Instance().Merge(applicable);
}

void StyleSheet::AddNode(StyleSheetNode&& node) {
	stylenode.emplace_back(std::move(node));
}

void StyleSheet::AddKeyframe(const std::string& identifier, const std::vector<float>& rule_values, const PropertyVector& properties) {
	auto& kf = keyframes[identifier];
	for (float selector : rule_values) {
		kf.blocks.emplace_back(KeyframeBlock { selector, properties });
	}
}

void StyleSheet::Sort() {
	int n = 0;
	for (auto& style : stylenode) {
		style.SetSpecificity(n++);
	}
	std::sort(stylenode.begin(), stylenode.end(), [](const StyleSheetNode& lhs, const StyleSheetNode& rhs) {
		return lhs.GetSpecificity() > rhs.GetSpecificity();
	});

	for (auto& [_, kf] : keyframes) {
		auto& blocks = kf.blocks;
		auto& property_ids = kf.property_ids;

		// Sort keyframes on selector value.
		std::sort(blocks.begin(), blocks.end(), [](const KeyframeBlock& a, const KeyframeBlock& b) { return a.normalized_time < b.normalized_time; });

		// Add all property names specified by any block
		if (blocks.size() > 0) property_ids.reserve(blocks.size() * blocks[0].properties.size());
		for (auto& block : blocks) {
			for (auto& v : block.properties)
				property_ids.push_back(v.id);
		}
		// Remove duplicate property names
		std::sort(property_ids.begin(), property_ids.end());
		property_ids.erase(std::unique(property_ids.begin(), property_ids.end()), property_ids.end());
		property_ids.shrink_to_fit();
	}
}

}
