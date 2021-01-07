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

#ifndef RMLUI_CORE_ELEMENTUTILITIES_H
#define RMLUI_CORE_ELEMENTUTILITIES_H

#include "Header.h"
#include "Types.h"

namespace Rml {

class Layout;
class Context;
class RenderInterface;
namespace Style { struct ComputedValues; }

/**
	Utility functions for dealing with elements.

	@author Lloyd Weehuizen
 */

class RMLUICORE_API ElementUtilities
{
public:
	/// Get the element with the given id.
	/// @param[in] root_element First element to check.
	/// @param[in] id ID of the element to look for.
	static Element* GetElementById(Element* root_element, const String& id);
	/// Get all elements with the given tag.
	/// @param[out] elements Resulting elements.
	/// @param[in] root_element First element to check.
	/// @param[in] tag Tag to search for.
	static void GetElementsByTagName(ElementList& elements, Element* root_element, const String& tag);
	/// Get all elements with the given class set on them.
	/// @param[out] elements Resulting elements.
	/// @param[in] root_element First element to check.
	/// @param[in] tag Class name to search for.
	static void GetElementsByClassName(ElementList& elements, Element* root_element, const String& class_name);

	/// Returns an element's density-independent pixel ratio, defined by it's context
	/// @param[in] element The element to determine the density-independent pixel ratio for.
	/// @return The density-independent pixel ratio of the context, or 1.0 if no context assigned.
	static float GetDensityIndependentPixelRatio(Element* element);
	
	/// Creates data views and data controllers if a data model applies to the element.
	/// Attributes such as 'data-' are used to create the views and controllers.
	/// @return True if a data view or controller was constructed.
	static bool ApplyDataViewsControllers(Element* element);

	/// Creates data views that use a raw inner xml content string to construct child elements.
	/// Right now, this only applies to the 'data-for' view.
	/// @return True if a data view was constructed.
	static bool ApplyStructuralDataViews(Element* element, const String& inner_rml);
};

} // namespace Rml
#endif
