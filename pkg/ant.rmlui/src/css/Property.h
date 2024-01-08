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
    str<uint8_t> PropertyEncode(const T& value) {
        strbuilder<uint8_t> b;
        b.append(PropertyType<T>);
        PropertyEncode(b, value);
        return b.release();
    }
    
    class Property {
    public:
        Property();
        Property(int attrib_id);
        Property(PropertyId id, str<uint8_t> str);

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

    float PropertyComputeX(const Element* e, const Property& p);
    float PropertyComputeY(const Element* e, const Property& p);
    float PropertyComputeZ(const Element* e, const Property& p);

    template <typename T>
    inline T InterpolateFallback(const T& p0, const T& p1, float alpha) {
        return alpha < 1.f ? p0 : p1;
    }
}
