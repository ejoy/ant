#pragma once

#include <css/Property.h>
#include <css/PropertyBinary.h>
#include <optional>
#include <tuple>

namespace Rml {
    class PropertyRaw;

    std::tuple<PropertyRaw, size_t> PropertyEncode(const Property& prop);

    class PropertyRaw {
    public:
        PropertyRaw(const uint8_t* data);
        const uint8_t* Raw() const;
        bool IsFloatUnit(PropertyUnit unit) const;
        std::optional<Property> Decode() const;
        std::string ToString() const;
        template <typename T>
            requires (!std::is_enum_v<T>)
        T Get() const {
            auto prop = Decode();
            assert(prop);
            return std::get<T>((PropertyVariant const&)*prop);
        }

        template <typename T>
            requires (std::is_enum_v<T>)
        T Get() const {
            static constexpr uint8_t index = (uint8_t)variant_index<PropertyVariant, PropertyKeyword>();
            strparser<uint8_t> p { m_data };
            if (index == p.pop<uint8_t>()) {
                return (T)p.pop<PropertyKeyword>();
            }
            assert(false);
            return {};
        }

        template <typename T>
        bool Has() const {
            static constexpr uint8_t index = (uint8_t)variant_index<PropertyVariant, T>();
            strparser<uint8_t> p { m_data };
            return index == p.pop<uint8_t>();
        }
    private:
        const uint8_t* m_data;
    };

    inline float PropertyComputeX(const Element* e, const PropertyRaw& p) {
        if (p.Has<PropertyKeyword>()) {
            switch (p.Get<PropertyKeyword>()) {
            default:
            case 0 /* left   */: return PropertyFloat { 0.0f, PropertyUnit::PERCENT }.ComputeW(e);
            case 1 /* center */: return PropertyFloat { 50.0f, PropertyUnit::PERCENT }.ComputeW(e);
            case 2 /* right  */: return PropertyFloat { 100.0f, PropertyUnit::PERCENT }.ComputeW(e);
            }
        }
        return p.Get<PropertyFloat>().ComputeW(e);
    }

    inline float PropertyComputeY(const Element* e, const PropertyRaw& p) {
        if (p.Has<PropertyKeyword>()) {
            switch (p.Get<PropertyKeyword>()) {
            default:
            case 0 /* top    */: return PropertyFloat { 0.0f, PropertyUnit::PERCENT }.ComputeH(e);
            case 1 /* center */: return PropertyFloat { 50.0f, PropertyUnit::PERCENT }.ComputeH(e);
            case 2 /* bottom */: return PropertyFloat { 100.0f, PropertyUnit::PERCENT }.ComputeH(e);
            }
        }
        return p.Get<PropertyFloat>().ComputeH(e);
    }

    inline float PropertyComputeZ(const Element* e, const PropertyRaw& p) {
        return p.Get<PropertyFloat>().Compute(e);
    }
}
