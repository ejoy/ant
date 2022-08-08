#pragma once

#include <core/ID.h>
#include <core/PropertyVector.h>
#include <core/StyleCache.h>
#include <unordered_map>
#include <vector>

namespace Rml {

class Element;
class StyleSheetNode;
class Stream;

struct KeyframeBlock {
	float normalized_time;  // [0, 1]
	PropertyVector properties;
};
struct Keyframes {
	std::vector<PropertyId> property_ids;
	std::vector<KeyframeBlock> blocks;
};

class StyleSheet {
public:
	StyleSheet();
	~StyleSheet();
	StyleSheet(const StyleSheet&) = delete;
	StyleSheet& operator=(const StyleSheet&) = delete;
	void Merge(const StyleSheet& sheet);
	void AddNode(StyleSheetNode && node);
	void AddKeyframe(const std::string& identifier, const std::vector<float>& rule_values, const PropertyVector& properties);
	void Sort();
	const Keyframes* GetKeyframes(const std::string& name) const;
	Style::PropertyCombination GetElementDefinition(const Element* element) const;

private:
	std::vector<StyleSheetNode> stylenode;
	std::unordered_map<std::string, Keyframes> keyframes;
};

}
