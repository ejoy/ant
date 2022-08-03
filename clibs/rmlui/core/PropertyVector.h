#pragma once

#include <unordered_map>
#include <vector>
#include <core/Property.h>
#include <stdint.h>

namespace Rml {

class Property;
enum class PropertyId : uint8_t;

namespace Style {
    struct PropertyKV {
        PropertyId id;
        Property   value;
    };
}

using PropertyVector = std::vector<Style::PropertyKV>;

}
