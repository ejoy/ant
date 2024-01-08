#include <css/PropertyView.h>
#include <css/StyleCache.h>

namespace Rml {
    PropertyView::PropertyView()
        : attrib_id(-1)
    {}

    PropertyView::PropertyView(int attrib_id)
        : attrib_id(attrib_id)
    {}

    PropertyView::PropertyView(PropertyId id, const std::span<uint8_t> value) {
        auto view = Style::Instance().CreateProperty(id, value);
        attrib_id = view.attrib_id;
        delete [] value.data();
    }

    PropertyView::operator bool () const {
         return attrib_id != -1;
    }

    strparser<uint8_t> PropertyView::CreateParser() const {
        auto view = Style::Instance().GetPropertyData(*this);
        return { view.data() };
    }

    int PropertyView::RawAttribId() const {
        return attrib_id;
    }

    bool PropertyView::IsFloatUnit(PropertyUnit unit) const {
        auto p = CreateParser();
        if (p.pop<uint8_t>() != PropertyType<PropertyFloat>) {
            return false;
        }
        auto const& v = p.pop<PropertyFloat>();
        return v.unit == unit;
    }

    std::string PropertyView::ToString() const {
        auto p = CreateParser();
        switch (p.pop<uint8_t>()) {
        case PropertyType<PropertyFloat>: {
            auto v = p.pop<PropertyFloat>();
            return v.ToString();
        }
        case PropertyType<PropertyKeyword>: {
            auto v = p.pop<PropertyKeyword>();
            return "<keyword," + std::to_string(v) + ">";
        }
        case PropertyType<Color>: {
            auto v = p.pop<Color>();
            return v.ToString();
        }
        case PropertyType<std::string>: {
            auto v = PropertyDecode(tag_v<std::string>, p);
            return v;
        }
        case PropertyType<Transform>: {
            auto v = PropertyDecode(tag_v<Transform>, p);
            return v.ToString();
        }
        case PropertyType<TransitionList>:
            return "<transition>";
        case PropertyType<AnimationList>:
            return "<animation>";
        }
        return {};
    }

    void PropertyRef::AddRef() {
        if (attrib_id == -1) {
            return;
        }
        Style::Instance().PropertyAddRef(*this);
    }

    void PropertyRef::Release() {
        if (attrib_id == -1) {
            return;
        }
        Style::Instance().PropertyRelease(*this);
    }

}
