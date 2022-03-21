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

#ifndef RMLUI_CORE_DATAMODEL_H
#define RMLUI_CORE_DATAMODEL_H

#include "../Include/RmlUi/Types.h"
#include "../Include/RmlUi/Traits.h"
#include "../Include/RmlUi/DataTypes.h"
#include "../Include/RmlUi/DataVariable.h"

namespace Rml {

class DataViews;
class DataControllers;
class Element;


class DataModel : NonCopyMoveable {
public:
	DataModel();
	~DataModel();

	void AddView(DataViewPtr view);
	void AddController(DataControllerPtr controller);

	bool BindVariable(const std::string& name, DataVariable variable);

	bool BindEventCallback(const std::string& name, DataEventFunc event_func);

	bool InsertAlias(Element* element, const std::string& alias_name, DataAddress replace_with_address);
	bool EraseAliases(Element* element);

	DataAddress ResolveAddress(const std::string& address_str, Element* element) const;
	const DataEventFunc* GetEventCallback(const std::string& name);

	DataVariable GetVariable(const DataAddress& address) const;
	bool GetVariableInto(const DataAddress& address, Variant& out_value) const;

	void DirtyVariable(const std::string& variable_name);
	bool IsVariableDirty(const std::string& variable_name) const;

	// Elements declaring 'data-model' need to be attached.
	void AttachModelRootElement(Element* element);
	ElementList GetAttachedModelRootElements() const;

	void OnElementRemove(Element* element);

	bool Update(bool clear_dirty_variables);

private:
	std::unique_ptr<DataViews> views;
	std::unique_ptr<DataControllers> controllers;

	std::unordered_map<std::string, DataVariable> variables;
	DirtyVariables dirty_variables;

	std::unordered_map<std::string, DataEventFunc> event_callbacks;

	using ScopedAliases = std::unordered_map<Element*, std::unordered_map<std::string, DataAddress>>;
	ScopedAliases aliases;

	std::unordered_set<Element*> attached_elements;
};


}
#endif
