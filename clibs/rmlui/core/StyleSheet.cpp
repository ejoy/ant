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

inline static bool StyleSheetNodeSort(const StyleSheetNode& lhs, const StyleSheetNode& rhs) {
	return lhs.GetSpecificity() > rhs.GetSpecificity();
}

StyleSheet::StyleSheet()
{}

StyleSheet::~StyleSheet()
{}

bool StyleSheet::LoadStyleSheet(Stream* stream, int begin_line_number) {
	StyleSheetParser parser;
	int n = parser.Parse(stream, *this, keyframes, begin_line_number);
	bool ok = n >= 0;
	if (!ok) {
		Log::Message(Log::Level::Error, "Failed to load style sheet in %s.", stream->GetSourceURL().c_str());
	}
	std::sort(stylenode.begin(), stylenode.end(), StyleSheetNodeSort);
	return ok;
}

void StyleSheet::CombineStyleSheet(const StyleSheet& other_sheet) {
	stylenode.assign(other_sheet.stylenode.begin(), other_sheet.stylenode.end());
	keyframes.reserve(keyframes.size() + other_sheet.keyframes.size());
	for (auto& other_keyframes : other_sheet.keyframes) {
		keyframes[other_keyframes.first] = other_keyframes.second;
	}
	std::sort(stylenode.begin(), stylenode.end(), StyleSheetNodeSort);
}

const Keyframes* StyleSheet::GetKeyframes(const std::string & name) const {
	auto it = keyframes.find(name);
	if (it != keyframes.end())
		return &(it->second);
	return nullptr;
}

Style::PropertyMap StyleSheet::GetElementDefinition(const Element* element) const {
	std::vector<Style::PropertyMap> applicable;
	for (auto& node : stylenode) {
		if (node.IsApplicable(element)) {
			applicable.push_back(node.GetProperties());
		}
	}
	return Style::Instance().CreateMap(applicable);
}

void StyleSheet::AddNode(StyleSheetNode&& node) {
	stylenode.emplace_back(std::move(node));
}

}
