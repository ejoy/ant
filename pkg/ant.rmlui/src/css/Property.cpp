#include <css/Property.h>
#include <css/StyleCache.h>
#include <core/ComputedValues.h>

namespace Rml {
    Property::Property()
        : attrib_id(-1)
    {}

    Property::Property(int attrib_id)
        : attrib_id(attrib_id)
    {}

    Property::Property(PropertyId id, str<uint8_t> str)
        : Property(Style::Instance().CreateProperty(id, str.span()))
    {}

    Property::operator bool () const {
         return attrib_id != -1;
    }

    PropertyView Property::GetView() const {
        auto view = Style::Instance().GetPropertyData(*this);
        return { view.data() };
    }

    int Property::RawAttribId() const {
        return attrib_id;
    }

    bool Property::IsFloatUnit(PropertyUnit unit) const {
        auto view = GetView();
        if (auto v = view.get_if<PropertyFloat>()) {
            return v->unit == unit;
        }
        return false;
    }

    struct ToStringVisitor {
        std::string operator()(const PropertyFloat& v) {
            return v.ToString();
        }
        std::string operator()(const PropertyKeyword& v) {
            return "<keyword," + std::to_string(v) + ">";
        }
        std::string operator()(const Color& v) {
            return v.ToString();
        }
        std::string operator()(tag<std::string>, PropertyBasicView view) {
            auto v = PropertyDecode(tag_v<std::string>, view);
            return v;
        }
        std::string operator()(tag<Transform>, PropertyBasicView view) {
            auto v = PropertyDecode(tag_v<Transform>, view);
            return v.ToString();
        }
        std::string operator()(tag<TransitionList>, PropertyBasicView view) {
            return "<transition>";
        }
        std::string operator()(tag<AnimationList>, PropertyBasicView view) {
            return "<animation>";
        }
        std::string operator()() {
            return "<unknown>";
        }
    };
    std::string Property::ToString() const {
        auto view = GetView();
        return view.visit(ToStringVisitor {});
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

    float PropertyComputeX(const Element* e, const Property& p) {
        if (p.Has<PropertyKeyword>()) {
            switch (p.GetEnum<Style::OriginX>()) {
            default:
            case Style::OriginX::Left: return PropertyFloat { 0.0f, PropertyUnit::PERCENT }.ComputeW(e);
            case Style::OriginX::Center: return PropertyFloat { 50.0f, PropertyUnit::PERCENT }.ComputeW(e);
            case Style::OriginX::Right: return PropertyFloat { 100.0f, PropertyUnit::PERCENT }.ComputeW(e);
            }
        }
        return p.Get<PropertyFloat>().ComputeW(e);
    }

    float PropertyComputeY(const Element* e, const Property& p) {
        if (p.Has<PropertyKeyword>()) {
            switch (p.GetEnum<Style::OriginY>()) {
            default:
            case Style::OriginY::Top: return PropertyFloat { 0.0f, PropertyUnit::PERCENT }.ComputeH(e);
            case Style::OriginY::Center: return PropertyFloat { 50.0f, PropertyUnit::PERCENT }.ComputeH(e);
            case Style::OriginY::Bottom: return PropertyFloat { 100.0f, PropertyUnit::PERCENT }.ComputeH(e);
            }
        }
        return p.Get<PropertyFloat>().ComputeH(e);
    }

    float PropertyComputeZ(const Element* e, const Property& p) {
        return p.Get<PropertyFloat>().Compute(e);
    }
}
