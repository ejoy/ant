#include <core/StyleSheet.h>
#include <core/StyleSheetNode.h>
#include <algorithm>

namespace Rml {

StyleSheet::StyleSheet()
{}

StyleSheet::~StyleSheet()
{}

template <typename Vec>
void vector_append(Vec& a, Vec const& b) {
	a.insert(std::end(a), std::begin(b), std::end(b));
}

void StyleSheet::Merge(const StyleSheet& other_sheet) {
	stylenode.insert(stylenode.end(), other_sheet.stylenode.begin(), other_sheet.stylenode.end());
	for (auto const& [identifier, other_kf] : other_sheet.keyframes) {
		auto& kf = keyframes[identifier];
		for (auto const& [id, value] : other_kf.properties) {
			vector_append(kf.properties[id], value);
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
	for (float time : rule_values) {
		for (auto const& [id, value] : properties) {
			kf.properties[id].emplace_back(KeyframeBlock {time, value} );
		}
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
		for (auto& [id, vec] : kf.properties) {
			std::sort(vec.begin(), vec.end(), [](const KeyframeBlock& a, const KeyframeBlock& b) { return a.normalized_time < b.normalized_time; });
		}
	}
}

}
