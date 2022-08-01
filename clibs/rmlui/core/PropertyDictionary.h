#pragma once

#include <unordered_map>
#include <vector>
#include <core/Property.h>
#include <core/StyleCache.h>
#include <stdint.h>

namespace Rml {

class Property;
enum class PropertyId : uint8_t;

using PropertyDictionary = std::unordered_map<PropertyId, Property>;
using PropertyVector = std::vector<Style::PropertyKV>;

inline PropertyDictionary ToDict(const PropertyVector& vec) {
    PropertyDictionary dict;
    for (auto const& v : vec) {
        dict.emplace(v.id, v.value);
    }
    return dict;
}

}
