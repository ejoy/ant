#pragma once

#include <core/Types.h>
#include <core/PropertyIdSet.h>
#include <yoga/Yoga.h>
#include <string>
#include <stdint.h>

namespace Rml {

class Element;
class Text;
class Property;
enum class PropertyId : uint8_t;

static inline PropertyIdSet GetLayoutProperties() {
	PropertyIdSet set;
	set.insert(PropertyId::Left);
	set.insert(PropertyId::Top);
	set.insert(PropertyId::Right);
	set.insert(PropertyId::Bottom);
	set.insert(PropertyId::MarginLeft);
	set.insert(PropertyId::MarginTop);
	set.insert(PropertyId::MarginRight);
	set.insert(PropertyId::MarginBottom);
	set.insert(PropertyId::PaddingLeft);
	set.insert(PropertyId::PaddingTop);
	set.insert(PropertyId::PaddingRight);
	set.insert(PropertyId::PaddingBottom);
	set.insert(PropertyId::BorderLeftWidth);
	set.insert(PropertyId::BorderTopWidth);
	set.insert(PropertyId::BorderRightWidth);
	set.insert(PropertyId::BorderBottomWidth);
	set.insert(PropertyId::Height);
	set.insert(PropertyId::Width);
	set.insert(PropertyId::MaxHeight);
	set.insert(PropertyId::MinHeight);
	set.insert(PropertyId::MaxWidth);
	set.insert(PropertyId::MinWidth);
	set.insert(PropertyId::Position);
	set.insert(PropertyId::Display);
	set.insert(PropertyId::Overflow);
	set.insert(PropertyId::AlignContent);
	set.insert(PropertyId::AlignItems);
	set.insert(PropertyId::AlignSelf);
	set.insert(PropertyId::Direction);
	set.insert(PropertyId::FlexDirection);
	set.insert(PropertyId::FlexWrap);
	set.insert(PropertyId::JustifyContent);
	set.insert(PropertyId::AspectRatio);
	set.insert(PropertyId::Flex);
	set.insert(PropertyId::FlexBasis);
	set.insert(PropertyId::FlexGrow);
	set.insert(PropertyId::FlexShrink);
	return set;
}

static inline const PropertyIdSet LayoutProperties = GetLayoutProperties();

class Layout {
public:
	enum class Overflow : uint8_t {
		Visible,
		Hidden,
		Scroll,
	};

	Layout();
	~Layout();

	Layout(const Layout&) = delete;
	Layout(Layout&&) = delete;
	Layout& operator=(const Layout&) = delete;
	Layout& operator=(Layout&&) = delete;

	void InitTextNode(Text* text);
	void CalculateLayout(Size const& size);
	void SetProperty(PropertyId id, const Property& property, const Element* element);
	
	bool IsDirty() const;
	void MarkDirty();
	std::string ToString() const;

	bool HasNewLayout();
	Overflow GetOverflow() const;

	bool IsVisible() const;
	void SetVisible(bool visible);

	Rect GetBounds() const;
	EdgeInsets<float> GetPadding() const;
	EdgeInsets<float> GetBorder() const;

	void InsertChild(Layout const& child, uint32_t index);
	void SwapChild(Layout const& child, uint32_t index);
	void RemoveChild(Layout const& child);
	void RemoveAllChildren();

private:
	YGNodeRef node;
};

}
