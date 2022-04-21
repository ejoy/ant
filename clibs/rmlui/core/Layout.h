#pragma once

#include <core/Types.h>
#include <yoga/Yoga.h>
#include <string>
#include <stdint.h>

namespace Rml {

class Element;
class Text;
class Property;
enum class PropertyId : uint8_t;

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
	void SetProperty(PropertyId id, const Property* property, const Element* element);
	
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
