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

#include "../Include/RmlUi/Factory.h"
#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/Document.h"
#include "../Include/RmlUi/Stream.h"
#include "../Include/RmlUi/StyleSheet.h"
#include "../Include/RmlUi/ElementText.h"
#include "../Include/RmlUi/ElementUtilities.h"
#include "../Include/RmlUi/StyleSheet.h"
#include "../Include/RmlUi/StringUtilities.h"
#include "../Include/RmlUi/Log.h"
#include "DataControllerDefault.h"
#include "DataViewDefault.h"
#include "PropertyParserColour.h"
#include "StyleSheetFactory.h"
#include "HtmlParser.h"

#include <algorithm>

namespace Rml {

// Data view instancers.
using DataViewInstancerMap = std::unordered_map< std::string, DataViewInstancer* >;
static DataViewInstancerMap data_view_instancers;

// Data controller instancers.
using DataControllerInstancerMap = std::unordered_map< std::string, DataControllerInstancer* >;
static DataControllerInstancerMap data_controller_instancers;

// Structural data view instancers.
using StructuralDataViewInstancerMap = std::unordered_map< std::string, DataViewInstancer* >;
static StructuralDataViewInstancerMap structural_data_view_instancers;

// Structural data view names.
static std::vector<std::string> structural_data_view_attribute_names;

// Default instancers are constructed and destroyed on Initialise and Shutdown, respectively.
struct DefaultInstancers {
	// Data binding views
	DataViewInstancerDefault<DataViewAttribute> data_view_attribute;
	DataViewInstancerDefault<DataViewAttributeIf> data_view_attribute_if;
	DataViewInstancerDefault<DataViewClass> data_view_class;
	DataViewInstancerDefault<DataViewIf> data_view_if;
	DataViewInstancerDefault<DataViewVisible> data_view_visible;
	DataViewInstancerDefault<DataViewRml> data_view_rml;
	DataViewInstancerDefault<DataViewStyle> data_view_style;
	DataViewInstancerDefault<DataViewText> data_view_text;
	DataViewInstancerDefault<DataViewValue> data_view_value;

	DataViewInstancerDefault<DataViewFor> structural_data_view_for;

	// Data binding controllers
	DataControllerInstancerDefault<DataControllerEvent> data_controller_event;
};

static std::unique_ptr<DefaultInstancers> default_instancers;

bool Factory::Initialise()
{
	default_instancers = std::make_unique<DefaultInstancers>();

	// Data binding views
	RegisterDataViewInstancer(&default_instancers->data_view_attribute,      "attr",    false);
	RegisterDataViewInstancer(&default_instancers->data_view_attribute_if,   "attrif",  false);
	RegisterDataViewInstancer(&default_instancers->data_view_class,          "class",   false);
	RegisterDataViewInstancer(&default_instancers->data_view_if,             "if",      false);
	RegisterDataViewInstancer(&default_instancers->data_view_visible,        "visible", false);
	RegisterDataViewInstancer(&default_instancers->data_view_rml,            "rml",     false);
	RegisterDataViewInstancer(&default_instancers->data_view_style,          "style",   false);
	RegisterDataViewInstancer(&default_instancers->data_view_text,           "text",    false);
	RegisterDataViewInstancer(&default_instancers->data_view_value,          "value",   false);
	RegisterDataViewInstancer(&default_instancers->structural_data_view_for, "for",     true );

	// Data binding controllers
	RegisterDataControllerInstancer(&default_instancers->data_controller_event, "event");

	return true;
}

void Factory::Shutdown()
{
	data_controller_instancers.clear();
	data_view_instancers.clear();
	structural_data_view_instancers.clear();
	structural_data_view_attribute_names.clear();
	default_instancers.reset();
}

void Factory::RegisterDataViewInstancer(DataViewInstancer* instancer, const std::string& name, bool is_structural_view)
{
	bool inserted = false;
	if (is_structural_view)
	{
		inserted = structural_data_view_instancers.emplace(name, instancer).second;
		if (inserted)
			structural_data_view_attribute_names.push_back(std::string("data-") + name);
	}
	else
	{
		inserted = data_view_instancers.emplace(name, instancer).second;
	}
	
	if (!inserted)
		Log::Message(Log::Level::Warning, "Could not register data view instancer '%s'. The given name is already registered.", name.c_str());
}

void Factory::RegisterDataControllerInstancer(DataControllerInstancer* instancer, const std::string& name)
{
	bool inserted = data_controller_instancers.emplace(name, instancer).second;
	if (!inserted)
		Log::Message(Log::Level::Warning, "Could not register data controller instancer '%s'. The given name is already registered.", name.c_str());
}

DataViewPtr Factory::InstanceDataView(const std::string& type_name, Element* element, bool is_structural_view)
{
	assert(element);

	if (is_structural_view)
	{
		auto it = structural_data_view_instancers.find(type_name);
		if (it != structural_data_view_instancers.end())
			return it->second->InstanceView(element);
	}
	else
	{
		auto it = data_view_instancers.find(type_name);
		if (it != data_view_instancers.end())
			return it->second->InstanceView(element);
	}
	return nullptr;
}

DataControllerPtr Factory::InstanceDataController(Element* element, const std::string& type_name)
{
	auto it = data_controller_instancers.find(type_name);
	if (it != data_controller_instancers.end())
		return it->second->InstanceController(element);
	return DataControllerPtr();
}

bool Factory::IsStructuralDataView(const std::string& type_name)
{
	return structural_data_view_instancers.find(type_name) != structural_data_view_instancers.end();
}

const std::vector<std::string>& Factory::GetStructuralDataViewAttributeNames()
{
	return structural_data_view_attribute_names;
}

} // namespace Rml
