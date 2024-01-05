#pragma once

#include <css/Property.h>
#include <css/PropertyBinary.h>
#include <optional>
#include <span>
#include <tuple>

namespace Rml {
    class PropertyView;

    PropertyView PropertyEncode(const Property& prop);

    class PropertyView {
    public:
        PropertyView(void* data, size_t size);
        PropertyView(std::span<uint8_t> data);
        void* RawData() const;
        size_t RawSize() const;
        bool IsFloatUnit(PropertyUnit unit) const;
        std::optional<Property> Decode() const;
        std::string ToString() const;
        template <typename T>
            requires (!std::is_enum_v<T>)
        T Get() const {
            static constexpr uint8_t index = (uint8_t)variant_index<PropertyVariant, T>();
            strparser<uint8_t> p { m_data.data() };
            if (index == p.pop<uint8_t>()) {
                return PropertyDecode(tag_v<T>, p);
            }
            throw std::runtime_error("decode property failed.");
        }

        template <typename T>
            requires (std::is_enum_v<T>)
        T GetEnum() const {
            static constexpr uint8_t index = (uint8_t)variant_index<PropertyVariant, PropertyKeyword>();
            strparser<uint8_t> p { m_data.data() };
            if (index == p.pop<uint8_t>()) {
                return (T)p.pop<PropertyKeyword>();
            }
            throw std::runtime_error("decode property failed.");
        }

        template <typename T>
        bool Has() const {
            static constexpr uint8_t index = (uint8_t)variant_index<PropertyVariant, T>();
            strparser<uint8_t> p { m_data.data() };
            return index == p.pop<uint8_t>();
        }
    private:
        std::span<uint8_t> m_data;
    };

    class PropertyGuard: public PropertyView {
    public:
        PropertyGuard(PropertyView prop)
            : PropertyView(prop)
        { }
        PropertyGuard(const PropertyGuard&) = delete;
        PropertyGuard& operator=(const PropertyGuard&) = delete;
        ~PropertyGuard() {
            delete[] (uint8_t*)RawData();
        }
    };

    inline bool operator==(const PropertyView& l, const PropertyView& r) {
        return l.RawData() == r.RawData();
    }

    inline float PropertyComputeX(const Element* e, const PropertyView& p) {
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

    inline float PropertyComputeY(const Element* e, const PropertyView& p) {
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

    inline float PropertyComputeZ(const Element* e, const PropertyView& p) {
        return p.Get<PropertyFloat>().Compute(e);
    }
}
