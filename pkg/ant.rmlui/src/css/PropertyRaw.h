#pragma once

#include <css/Property.h>
#include <optional>
#include <tuple>

namespace Rml {
    class PropertyRaw {
    public:
        PropertyRaw(const uint8_t* data);
        const uint8_t* Raw() const;
        bool IsFloatUnit(PropertyUnit unit) const;
    private:
        const uint8_t* m_data;
    };

    std::tuple<PropertyRaw, size_t> PropertyEncode(const Property& prop);
    std::optional<Property> PropertyDecode(const PropertyRaw& prop);
}
