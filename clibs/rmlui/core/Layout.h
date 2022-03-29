#pragma once

#include "Types.h"
#include <yoga/Yoga.h>

namespace Rml {

class Element;
class ElementText;

class Layout {
public:
	struct Metrics {
		Rect frame;
		Rect content;
		EdgeInsets<float> paddingWidth{};
		EdgeInsets<float> borderWidth{};
		EdgeInsets<float> scrollInsets{};
		bool visible = true;

		bool operator==(const Metrics& rhs) const {
			return std::tie(frame, paddingWidth, borderWidth, visible) == std::tie(rhs.frame, rhs.paddingWidth, rhs.borderWidth, visible);
		}
		bool operator!=(const Metrics& rhs) const {
			return !(*this == rhs);
		}
	};

	enum class Overflow {
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

	void SetElementText(ElementText* element);
	void CalculateLayout(Size const& size);
	void SetProperty(PropertyId id, const Property* property, Element* element);
	
	bool IsDirty();
	void MarkDirty();
	std::string ToString() const;

	bool HasNewLayout() const;
	bool UpdateVisible(Layout::Metrics& metrics);
	void UpdateMetrics(Layout::Metrics& metrics, const Rect& child);
	void UpdateScrollOffset(Size& scrollOffset, Layout::Metrics const& metrics) const;
	Overflow GetOverflow() const;
	void SetVisible(bool visible);

	void InsertChild(Layout const& child, uint32_t index);
	void SwapChild(Layout const& child, uint32_t index);
	void RemoveChild(Layout const& child);
	void RemoveAllChildren();

private:
	YGNodeRef node;
};

}
