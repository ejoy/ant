#pragma once

#include <css/Property.h>
#include <css/PropertyBinary.h>
#include <optional>
#include <span>

namespace Rml {
    class PropertyView {
    public:
        PropertyView();
        PropertyView(int attrib_id);
        PropertyView(PropertyId id, const Property& prop);
        explicit operator bool () const;
        int RawAttribId() const;
        bool IsFloatUnit(PropertyUnit unit) const;
        std::optional<Property> Decode() const;
        std::string ToString() const;
        template <typename T>
            requires (!std::is_enum_v<T>)
        T Get() const {
            static constexpr uint8_t index = (uint8_t)variant_index<Property, T>();
            auto p = CreateParser();
            if (index == p.pop<uint8_t>()) {
                return PropertyDecode(tag_v<T>, p);
            }
            throw std::runtime_error("decode property failed.");
        }

        template <typename T>
            requires (std::is_enum_v<T>)
        T GetEnum() const {
            static constexpr uint8_t index = (uint8_t)variant_index<Property, PropertyKeyword>();
            auto p = CreateParser();
            if (index == p.pop<uint8_t>()) {
                return (T)p.pop<PropertyKeyword>();
            }
            throw std::runtime_error("decode property failed.");
        }

        template <typename T>
        bool Has() const {
            static constexpr uint8_t index = (uint8_t)variant_index<Property, T>();
            auto p = CreateParser();
            return index == p.pop<uint8_t>();
        }
    private:
        strparser<uint8_t> CreateParser() const;
    
    private:
        int attrib_id;
    };

    inline bool operator==(const PropertyView& l, const PropertyView& r) {
        return l.RawAttribId() == r.RawAttribId();
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

    template <typename T>
    inline T InterpolateFallback(const T& p0, const T& p1, float alpha) {
        return alpha < 1.f ? p0 : p1;
    }
}
