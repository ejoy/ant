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

#ifndef RMLUI_CORE_FACTORY_H
#define RMLUI_CORE_FACTORY_H

#include "Platform.h"
#include "Types.h"
#include <string>

namespace Rml {

class DataControllerInstancer;
class DataViewInstancer;
class Element;
class Document;
class EventListener;
class EventListenerInstancer;
class StyleSheet;
class PropertyDictionary;
class PropertySpecification;

/**
	The Factory contains a registry of instancers for different types.

	All instantiation of these rmlui types should go through the factory
	so that scripting API's can bind in new types.

	@author Lloyd Weehuizen
 */

class Factory
{
public:
	/// Initialise the element factory
	static bool Initialise();
	/// Cleanup and shutdown the factory
	static void Shutdown();

	/// Instances a text element containing a string.
	/// More than one element may be instanced if the string contains RML or RML is introduced during translation.
	/// @param[in] parent The element any instanced elements will be parented to.
	/// @param[in] text The text to instance the element (or elements) from.
	/// @return True if the string was parsed without error, false otherwise.
	static bool InstanceElementText(Element* parent, const std::string& text);

	/// Register an instancer for data views.
	/// Structural views start a special XML parsing procedure when encountering a declaration of the view. Instead of instancing
	/// children elements, the raw inner XML/RML contents are submitted to the initializing procedure of the view.
	/// @param[in] instancer  The instancer to be called.
	/// @param[in] type_name  The type name of the view, determines the element attribute that is used to initialize it.
	/// @param[in] is_structural_view  Set true if the view should be parsed as a structural view.
	/// @lifetime The instancer must be kept alive until after the call to Rml::Shutdown.
	static void RegisterDataViewInstancer(DataViewInstancer* instancer, const std::string& type_name, bool is_structural_view = false);

	/// Register an instancer for data controllers.
	/// @param[in] instancer  The instancer to be called.
	/// @param[in] type_name  The type name of the controller, determines the element attribute that is used to initialize it.
	/// @lifetime The instancer must be kept alive until after the call to Rml::Shutdown.
	static void RegisterDataControllerInstancer(DataControllerInstancer* instancer, const std::string& type_name);

	/// Instance the data view with the given type name.
	static DataViewPtr InstanceDataView(const std::string& type_name, Element* element, bool is_structural_view);

	/// Instance the data controller with the given type name.
	static DataControllerPtr InstanceDataController(Element* element, const std::string& type_name);

	/// Returns true if the given type name is a structural data view.
	static bool IsStructuralDataView(const std::string& type_name);

	/// Returns the list of element attribute names with an associated structural data view instancer.
	static const std::vector<std::string>& GetStructuralDataViewAttributeNames();

private:
	Factory();
	~Factory();
};

} // namespace Rml
#endif
