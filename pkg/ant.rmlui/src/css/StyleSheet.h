#pragma once

#include <core/ID.h>
#include <css/StyleCache.h>
#include <map>
#include <vector>

namespace Rml {

class Element;
class StyleSheetNode;

struct AnimationKey {
	AnimationKey(float time, const Property& value)
		: time(time)
		, prop(value) {
		prop.AddRef();
	}
	float time;
	PropertyRef prop;
};

struct AnimationKeyframe: public std::vector<AnimationKey> {
};

using AnimationKeyframes = std::map<PropertyId, AnimationKeyframe>;

class StyleSheet {
public:
	StyleSheet();
	~StyleSheet();
	StyleSheet(const StyleSheet&) = delete;
	StyleSheet& operator=(const StyleSheet&) = delete;
	void AddNode(StyleSheetNode && node);
	void AddKeyframe(const std::string& identifier, const std::vector<float>& rule_values, const PropertyVector& properties);
	void Sort();
	const AnimationKeyframes* GetKeyframes(const std::string& name) const;
	Style::TableRef GetElementDefinition(const Element* element) const;

private:
	std::vector<StyleSheetNode> stylenode;
	std::map<std::string, AnimationKeyframes> keyframes;
};

}
