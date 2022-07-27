#pragma once

#include <core/ID.h>
#include <core/PropertyDictionary.h>
#include <core/SharedPtr.h>
#include <memory>
#include <unordered_map>
#include <vector>

namespace Rml {

class Element;
class StyleSheetNode;
class StyleSheetPropertyDictionary;
class Stream;

struct KeyframeBlock {
	float normalized_time;  // [0, 1]
	PropertyDictionary properties;
};
struct Keyframes {
	std::vector<PropertyId> property_ids;
	std::vector<KeyframeBlock> blocks;
};
using KeyframesMap = std::unordered_map<std::string, Keyframes>;

class StyleSheet {
public:
	typedef std::vector<StyleSheetNode*> NodeIndex;
	StyleSheet();
	virtual ~StyleSheet();
	StyleSheet(const StyleSheet&) = delete;
	StyleSheet& operator=(const StyleSheet&) = delete;
	bool LoadStyleSheet(Stream* stream, int begin_line_number = 1);
	void CombineStyleSheet(const StyleSheet& sheet);
	void BuildNodeIndex();
	const Keyframes* GetKeyframes(const std::string& name) const;
	SharedPtr<StyleSheetPropertyDictionary> GetElementDefinition(const Element* element) const;

	void Reset() {}

private:
	std::unique_ptr<StyleSheetNode> root;
	int specificity_offset;
	KeyframesMap keyframes;
	NodeIndex styled_node_index;
};

}
