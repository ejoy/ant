#include <css/PropertyRaw.h>

namespace Rml {
    PropertyRaw PropertyEncode(const Property& prop) {
        strbuilder<uint8_t> b;
        PropertyEncode(b, (PropertyVariant const&)prop);
        return PropertyRaw { b.string() };
    }

    PropertyRaw::PropertyRaw(void* data, size_t size)
        : m_data { (uint8_t*)data, size }
    {}

    PropertyRaw::PropertyRaw(std::span<uint8_t> data)
        : m_data(data)
    {}

    void* PropertyRaw::RawData() const {
        return (void*)m_data.data();
    }

    size_t PropertyRaw::RawSize() const {
        return m_data.size();
    }

    std::optional<Property> PropertyRaw::Decode() const {
        strparser<uint8_t> p { m_data.data() };
        return PropertyDecode(tag_v<Property>, p);
    }

    bool PropertyRaw::IsFloatUnit(PropertyUnit unit) const {
        static constexpr uint8_t index = (uint8_t)variant_index<PropertyVariant, PropertyFloat>();
        strparser<uint8_t> p { m_data.data() };
        if (index != p.pop<uint8_t>()) {
            return false;
        }
        auto const& v = p.pop<PropertyFloat>();
        return v.unit == unit;
    }

    std::string PropertyRaw::ToString() const {
        strparser<uint8_t> p { m_data.data() };
        switch (p.pop<uint8_t>()) {
        case (uint8_t)variant_index<PropertyVariant, PropertyFloat>(): {
            auto v = p.pop<PropertyFloat>();
            return v.ToString();
        }
        case (uint8_t)variant_index<PropertyVariant, PropertyKeyword>(): {
            auto v = p.pop<PropertyKeyword>();
            return "<keyword," + std::to_string(v) + ">";
        }
        case (uint8_t)variant_index<PropertyVariant, Color>(): {
            auto v = p.pop<Color>();
            return v.ToString();
        }
        case (uint8_t)variant_index<PropertyVariant, std::string>(): {
            auto v = PropertyDecode(tag_v<std::string>, p);
            return v;
        }
        case (uint8_t)variant_index<PropertyVariant, Transform>(): {
            auto v = PropertyDecode(tag_v<Transform>, p);
            return v.ToString();
        }
        case (uint8_t)variant_index<PropertyVariant, TransitionList>():
            return "<transition>";
        case (uint8_t)variant_index<PropertyVariant, AnimationList>():
            return "<animation>";
        }
        return {};
    }
}
