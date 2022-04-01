#pragma once

#include <unordered_map>
#include <core/Property.h>
#include <stdint.h>

namespace Rml {

class Property;
enum class PropertyId : uint8_t;

using PropertyDictionary = std::unordered_map<PropertyId, Property>;

}
