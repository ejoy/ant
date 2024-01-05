#include <css/PropertyView.h>

namespace Rml {
    PropertyView PropertyEncode(const Property& prop) {
        strbuilder<uint8_t> b;
        PropertyEncode(b, prop);
        return PropertyView { b.string() };
    }

    PropertyView::PropertyView(void* data, size_t size)
        : m_data { (uint8_t*)data, size }
    {}

    PropertyView::PropertyView(std::span<uint8_t> data)
        : m_data(data)
    {}

    void* PropertyView::RawData() const {
        return (void*)m_data.data();
    }

    size_t PropertyView::RawSize() const {
        return m_data.size();
    }

    std::optional<Property> PropertyView::Decode() const {
        strparser<uint8_t> p { m_data.data() };
        return PropertyDecode(tag_v<Property>, p);
    }

    bool PropertyView::IsFloatUnit(PropertyUnit unit) const {
        static constexpr uint8_t index = (uint8_t)variant_index<Property, PropertyFloat>();
        strparser<uint8_t> p { m_data.data() };
        if (index != p.pop<uint8_t>()) {
            return false;
        }
        auto const& v = p.pop<PropertyFloat>();
        return v.unit == unit;
    }

    std::string PropertyView::ToString() const {
        strparser<uint8_t> p { m_data.data() };
        switch (p.pop<uint8_t>()) {
        case (uint8_t)variant_index<Property, PropertyFloat>(): {
            auto v = p.pop<PropertyFloat>();
            return v.ToString();
        }
        case (uint8_t)variant_index<Property, PropertyKeyword>(): {
            auto v = p.pop<PropertyKeyword>();
            return "<keyword," + std::to_string(v) + ">";
        }
        case (uint8_t)variant_index<Property, Color>(): {
            auto v = p.pop<Color>();
            return v.ToString();
        }
        case (uint8_t)variant_index<Property, std::string>(): {
            auto v = PropertyDecode(tag_v<std::string>, p);
            return v;
        }
        case (uint8_t)variant_index<Property, Transform>(): {
            auto v = PropertyDecode(tag_v<Transform>, p);
            return v.ToString();
        }
        case (uint8_t)variant_index<Property, TransitionList>():
            return "<transition>";
        case (uint8_t)variant_index<Property, AnimationList>():
            return "<animation>";
        }
        return {};
    }
}
