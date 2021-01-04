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

class ElementText;

class RMLUICORE_API Layout
{
public:
	enum Area
	{
		MARGIN = 0,
		BORDER = 1,
		PADDING = 2,
		CONTENT = 3,
		NUM_AREAS = 3,		// ignores CONTENT
	};

	enum Edge
	{
		TOP = 0,
		RIGHT = 1,
		BOTTOM = 2,
		LEFT = 3,
		NUM_EDGES = 4
	};

	/// Initialises a zero-sized box.
	Layout();
	~Layout();

	Layout(const Layout&) = delete;
	Layout(Layout&&) = delete;

	Layout& operator=(const Layout&) = delete;
	Layout& operator=(Layout&&) = delete;

	/// Returns the top-left position of one of the box's areas, relative to the top-left of the border area. This
	/// means the position of the margin area is likely to be negative.
	/// @param area[in] The desired area.
	/// @return The position of the area.
	Vector2f GetPosition(Area area = Layout::CONTENT) const;
	/// Returns the size of one of the box's areas. This will include all inner areas.
	/// @param area[in] The desired area.
	/// @return The size of the requested area.
	Vector2f GetSize(Area area = Layout::CONTENT) const;

	/// Returns the size of one of the area edges.
	/// @param area[in] The desired area.
	/// @param edge[in] The desired edge.
	/// @return The size of the requested area edge.
	float GetEdge(Area area, Edge edge) const;

	void CalculateLayout(float width, float height);
	Vector4f GetBounds() const;

	void SetWidth(float v);
	void SetHeight(float v);

	void InsertChild(Layout const& child, uint32_t index);
	void SwapChild(Layout const& child, uint32_t index);
	void RemoveChild(Layout const& child);
	void RemoveAllChildren();
	void SetProperty(PropertyId id, const Property* property, float font_size, float document_font_size, float dp_ratio);

	void SetElementText(ElementText* element);
	void MarkDirty();

	std::string ToString() const;

	/// Compares the size of the content area and the other area edges.
	/// @return True if the boxes represent the same area.
	bool operator==(const Layout& rhs) const = delete;
	/// Compares the size of the content area and the other area edges.
	/// @return True if the boxes do not represent the same area.
	bool operator!=(const Layout& rhs) const = delete;

private:
	YGNodeRef node;
};

} // namespace Rml
#endif
