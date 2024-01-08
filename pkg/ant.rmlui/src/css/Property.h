#pragma once

#include <core/Color.h>
#include <core/Animation.h>
#include <core/Transform.h>
#include <css/PropertyFloat.h>
#include <css/PropertyKeyword.h>
#include <optional>
#include <span>
#include <variant>
#include <string>
#include <css/PropertyBinary.h>


namespace Rml {
    using PropertyVariant = std::variant<
        PropertyFloat,
        PropertyKeyword,
        Color,
        std::string,
        Transform,
        TransitionList,
        AnimationList
    >;

    template <typename T>
    constexpr uint8_t PropertyType = (uint8_t)variant_index<PropertyVariant, T>();

    template <typename T>
    std::span<uint8_t> PropertyEncode(const T& value) {
        strbuilder<uint8_t> b;
        b.append(PropertyType<T>);
        PropertyEncode(b, value);
        return b.string();
    }
    
    class Property {
    public:
        Property();
        Property(int attrib_id);
        Property(PropertyId id, std::span<uint8_t> value);

        template <typename T>
        Property(PropertyId id, const T& value)
        : Property(id, PropertyEncode<T>(value))
        {}

        explicit operator bool () const;
        int RawAttribId() const;
        bool IsFloatUnit(PropertyUnit unit) const;
        std::string ToString() const;
        template <typename T>
            requires (!std::is_enum_v<T>)
        T Get() const {
            auto p = CreateParser();
            if (p.pop<uint8_t>() == PropertyType<T>) {
                return PropertyDecode(tag_v<T>, p);
            }
            throw std::runtime_error("decode property failed.");
        }

        template <typename T>
            requires (std::is_enum_v<T>)
        T GetEnum() const {
            auto p = CreateParser();
            if (p.pop<uint8_t>() == PropertyType<PropertyKeyword>) {
                return (T)p.pop<PropertyKeyword>();
            }
            throw std::runtime_error("decode property failed.");
        }

        template <typename T>
        bool Has() const {
            auto p = CreateParser();
            return p.pop<uint8_t>() == PropertyType<T>;
        }

        strparser<uint8_t> CreateParser() const;
    
    protected:
        int attrib_id;
    };
    static_assert(sizeof(Property) == sizeof(int));

    class PropertyRef: public Property {
    public:
        PropertyRef()
        {}
        PropertyRef(Property view)
            : Property(view) {
            AddRef();
        }
        ~PropertyRef() {
            Release();
        }
        PropertyRef(PropertyRef&& rhs)
            : Property(rhs) {
            rhs.attrib_id = -1;
        }
        PropertyRef(const PropertyRef& rhs)
            : Property(rhs) {
            AddRef();
        }
        PropertyRef& operator=(PropertyRef&& rhs) {
            if (this != &rhs) {
                Release();
                attrib_id = rhs.attrib_id;
                rhs.attrib_id = -1;
            }
            return *this;
        }
        PropertyRef& operator=(const PropertyRef& rhs) {
            if (this != &rhs) {
                Release();
                attrib_id = rhs.attrib_id;
                AddRef();
            }
            return *this;
        }
        void AddRef();
        void Release();
    };
    
    using PropertyVector = std::vector<Property>;

    inline bool operator==(const Property& l, const Property& r) {
        return l.RawAttribId() == r.RawAttribId();
    }

    inline float PropertyComputeX(const Element* e, const Property& p) {
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

    inline float PropertyComputeY(const Element* e, const Property& p) {
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

    inline float PropertyComputeZ(const Element* e, const Property& p) {
        return p.Get<PropertyFloat>().Compute(e);
    }

    template <typename T>
    inline T InterpolateFallback(const T& p0, const T& p1, float alpha) {
        return alpha < 1.f ? p0 : p1;
    }
}
