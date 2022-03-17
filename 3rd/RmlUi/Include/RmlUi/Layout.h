/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2008-2010 CodePoint Ltd, Shift Technology Ltd
 * Copyright (c) 2019 The RmlUi Team, and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#ifndef RMLUI_CORE_BOX_H
#define RMLUI_CORE_BOX_H

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
		EdgeInsets<float> scrollInset{};
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
	void UpdateMetrics(Layout::Metrics& metrics, Rect& child);
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
#endif
