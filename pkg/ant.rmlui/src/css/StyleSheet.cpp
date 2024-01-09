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

Style::TableRef StyleSheet::GetElementDefinition(const Element* element) const {
	std::vector<Style::TableValue> applicable;
	for (auto& node : stylenode) {
		if (node.IsApplicable(element)) {
			applicable.emplace_back(node.GetProperties());
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
		for (auto const& v : properties) {
			auto id = Style::Instance().GetPropertyId(v);
			kf[id].emplace_back(time, v);
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
			std::sort(kf.begin(), kf.end(), [](const AnimationKey& a, const AnimationKey& b) { return a.time < b.time; });
			if (kf.empty()) {
				Log::Message(Log::Level::Warning, "Keyframe has no rule.");
				it = kfs.erase(it);
				continue;
			}
			if (kf.front().time != 0.f) {
				Log::Message(Log::Level::Warning, "Keyframe has no from rule.");
				it = kfs.erase(it);
				continue;
			}
			if (kf.back().time != 1.f) {
				Log::Message(Log::Level::Warning, "Keyframe has no to rule.");
				it = kfs.erase(it);
				continue;
			}
			if (kf.size() > 255) {
				Log::Message(Log::Level::Warning, "Keyframe has too many rules.");
				it = kfs.erase(it);
				continue;
			}
			++it;
		}
	}
}

}
