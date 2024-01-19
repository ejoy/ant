#pragma once

#include <core/Color.h>
#include <core/Animation.h>
#include <core/Transform.h>
#include <css/PropertyFloat.h>
#include <css/PropertyKeyword.h>
#include <string>
#include <css/PropertyBinary.h>

namespace Rml {
    using PropertyView = PropertyVariantView<PropertyFloat, PropertyKeyword, Color, std::string, Transform, TransitionList, Animation>;

    template <typename T>
    str<uint8_t> PropertyEncode(const T& value) {
        strbuilder<uint8_t> b;
        b.append(PropertyView::Index<T>);
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
            auto view = GetView();
            if constexpr (std::is_trivially_destructible_v<T>) {
                return view.get<T>();
            }
            else {
                auto subview = view.get_view<T>();
                return PropertyDecode(tag_v<T>, subview);
            }
        }

        template <typename T>
            requires (!std::is_enum_v<T>)
        std::optional<T> GetIf() const {
            auto view = GetView();
            if constexpr (std::is_trivially_destructible_v<T>) {
                if (auto v = view.get_if<T>()) {
                    return *v;
                }
            }
            else {
                if (auto subview = view.get_view_if<T>()) {
                    return PropertyDecode(tag_v<T>, *subview);
                }
            }
            return std::nullopt;
        }

        template <typename T>
            requires (std::is_enum_v<T>)
        T GetEnum() const {
            auto view = GetView();
            return (T)view.get<PropertyKeyword>();
        }

        template <typename T>
        bool Has() const {
            auto view = GetView();
            return view.get_index() == PropertyView::Index<T>;
        }

        PropertyView GetView() const;
    
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

    template <typename Visitor>
    auto PropertyVisit(Visitor&& vis, const Property& p0) {
        auto view0 = p0.GetView();
        return view0.visit(std::forward<Visitor>(vis));
    }

    template <typename Visitor>
    auto PropertyVisit(Visitor&& vis, const Property& p0, const Property& p1) {
        auto view0 = p0.GetView();
        auto view1 = p1.GetView();
        return view0.visit(std::forward<Visitor>(vis), view1);
    }

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
