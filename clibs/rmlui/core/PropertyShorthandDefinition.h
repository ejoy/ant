#pragma once

#include <core/ID.h>
#include <variant>
#include <vector>

namespace Rml {

enum class ShorthandType : uint8_t;
class PropertyDefinition;
class ShorthandDefinition;

using DefinitionVariant = std::variant<const PropertyDefinition*, const ShorthandDefinition*>;

struct ShorthandItem {
	DefinitionVariant definition;
	bool optional;
};

class ShorthandDefinition {
public:
	ShorthandId GetId() const { return id; }

	ShorthandId id;
	ShorthandType type;
	std::vector<ShorthandItem> items;
};

}