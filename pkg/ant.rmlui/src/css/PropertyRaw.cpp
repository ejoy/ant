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

    struct ToStringVisitor {
        std::string operator()(const PropertyFloat& p) {
            return p.ToString();
        }
        std::string operator()(const PropertyKeyword& p) {
            return "<keyword," + std::to_string(p) + ">";
        }
        std::string operator()(const Color& p) {
            return p.ToString();
        }
        std::string operator()(const std::string& p) {
            return p;
        }
        std::string operator()(const Transform& p) {
            return p.ToString();
        }
        std::string operator()(const TransitionList& p) {
            return "<transition>";
        }
        std::string operator()(const AnimationList& p) {
            return "<animation>";
        }
    };

    std::string PropertyRaw::ToString() const {
        //TODO rewrite
        if (auto prop = Decode()) {
            return std::visit(ToStringVisitor{}, (const PropertyVariant&)*prop);
        }
        return {};
    }
}
