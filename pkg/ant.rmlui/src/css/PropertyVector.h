#pragma once

#include <css/Property.h>
#include <vector>
#include <stdint.h>

namespace Rml {

enum class PropertyId : uint8_t;

struct PropertyKV {
    PropertyId id;
    Property   value;
    PropertyKV(PropertyId id, Property&&  value)
        : id(id)
        , value(std::move(value))
    {}
};

using PropertyVector = std::vector<PropertyKV>;

}
