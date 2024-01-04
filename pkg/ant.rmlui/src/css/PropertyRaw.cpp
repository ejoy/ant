#include <css/PropertyRaw.h>
#include <css/PropertyBinary.h>

namespace Rml {
    std::tuple<PropertyRaw, size_t> PropertyEncode(const Property& prop) {
        strbuilder<uint8_t> b;
        PropertyEncode(b, (PropertyVariant const&)prop);
        auto view = b.string();
        return {
            PropertyRaw { view.data() },
            view.size(),
        };
    }

    std::optional<Property> PropertyDecode(const PropertyRaw& prop) {
        strparser<uint8_t> p {(const uint8_t*)prop.Raw()};
        return PropertyDecode(tag_v<Property>, p);
    }

    PropertyRaw::PropertyRaw(const uint8_t* data)
        : m_data(data)
    {}

    const uint8_t* PropertyRaw::Raw() const {
        return m_data;
    }

    bool PropertyRaw::IsFloatUnit(PropertyUnit unit) const {
        static constexpr uint8_t index = (uint8_t)variant_index<PropertyVariant, PropertyFloat>();
        strparser<uint8_t> p {m_data};
        if (index != p.pop<uint8_t>()) {
            return false;
        }
        auto const& v = p.pop<PropertyFloat>();
        return v.unit == unit;
    }
}
