#include <css/StyleSheet.h>
#include <css/StyleSheetNode.h>
#include <util/Log.h>
#include <algorithm>

namespace Rml {

StyleSheet::StyleSheet()
{}

StyleSheet::~StyleSheet()
{}

void StyleSheet::Merge(const StyleSheet& other_sheet) {
	stylenode.insert(stylenode.end(), other_sheet.stylenode.begin(), other_sheet.stylenode.end());
	for (auto const& [identifier, other_kf] : other_sheet.keyframes) {
		auto [_, suc] = keyframes.emplace(identifier, other_kf);
		if (!suc) {
			Log::Message(Log::Level::Warning, "Redfined keyframe.");
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
			if (time == 0) {
				kf[id].from = value;
			}
			else if (time == 1) {
				kf[id].to = value;
			}
			else {
				kf[id].keys.emplace_back(time, value);
			}
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
	for (auto& [_, kfs] : keyframes) {
		for (auto it = kfs.begin(); it != kfs.end();) {
			auto& kf = it->second;
			std::sort(kf.keys.begin(), kf.keys.end(), [](const AnimationKey& a, const AnimationKey& b) { return a.time < b.time; });
			if (!kf.from) {
				Log::Message(Log::Level::Warning, "Keyframe has no from rule.");
				it = kfs.erase(it);
				continue;
			}
			if (!kf.to) {
				Log::Message(Log::Level::Warning, "Keyframe has no to rule.");
				it = kfs.erase(it);
				continue;
			}
			++it;
		}
	}
}

}
