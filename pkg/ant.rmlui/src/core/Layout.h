#pragma once

#include <core/Types.h>
#include <css/PropertyIdSet.h>
#include <string>
#include <stdint.h>

typedef struct YGNode* YGNodeRef;

namespace Rml {

class Element;
class Property;
enum class PropertyId : uint8_t;

static constexpr inline PropertyIdSet GetLayoutProperties() {
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
	set.insert(PropertyId::ColumnGap);
	set.insert(PropertyId::RowGap);
	set.insert(PropertyId::Gap);
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

static constexpr inline const PropertyIdSet LayoutProperties = GetLayoutProperties();

class Layout {
public:
	struct UseElement {};
	struct UseText {};

	enum class Overflow : uint8_t {
		Visible = 0,
		Hidden,
		Scroll,
	};

	enum class Type : uint8_t {
		Element = 0,
		Text,
	};

	Layout(UseElement);
	Layout(UseText, void* context);
	~Layout();

	Layout(const Layout&) = delete;
	Layout(Layout&&) = delete;
	Layout& operator=(const Layout&) = delete;
	Layout& operator=(Layout&&) = delete;

	void CalculateLayout(Size const& size);
	void SetProperty(PropertyId id, const Property& property, const Element* element);
	
	bool IsDirty() const;
	void MarkDirty();
	void Print() const;

	bool HasNewLayout();
	Overflow GetOverflow() const;
	Type GetType() const;

	bool IsVisible() const;
	void SetVisible(bool visible);

	Rect GetBounds() const;
	EdgeInsets<float> GetPadding() const;
	EdgeInsets<float> GetBorder() const;

	void InsertChild(Layout const& child, size_t index);
	void RemoveChild(Layout const& child);
	void RemoveAllChildren();

private:
	float YGValueToFloat(float v) const;

private:
	YGNodeRef node;
};

}
