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

#include "databinding/DataModel.h"
#include "core/Element.h"
#include "core/Log.h"
#include "core/StringUtilities.h"
#include "databinding/DataEvent.h"
#include "databinding/DataView.h"

namespace Rml {

static DataAddress ParseAddress(const std::string& address_str) {
	std::vector<std::string> list;
	StringUtilities::ExpandString(list, address_str, '.');

	DataAddress address;
	address.reserve(list.size() * 2);

	for (const auto& item : list)
	{
		if (item.empty())
			return DataAddress();

		size_t i_open = item.find('[', 0);
		if (i_open == 0)
			return DataAddress();

		address.emplace_back(item.substr(0, i_open));

		while (i_open != std::string::npos)
		{
			size_t i_close = item.find(']', i_open + 1);
			if (i_close == std::string::npos)
				return DataAddress();

			int index = FromString<int>(item.substr(i_open + 1, i_close - i_open), -1);
			if (index < 0)
				return DataAddress();

			address.emplace_back(index);

			i_open = item.find('[', i_close + 1);
		}
		// TODO: Abort on invalid characters among [ ] and after the last found bracket?
	}

	assert(!address.empty() && !address[0].name.empty());

	return address;
}

// Returns an error string on error, or nullptr on success.
static const char* LegalVariableName(const std::string& name) {
	static std::unordered_set<std::string> reserved_names{ "it", "ev", "true", "false", "size", "literal" };
	
	if (name.empty())
		return "Name cannot be empty.";
	
	const std::string name_lower = StringUtilities::ToLower(name);

	const char first = name_lower.front();
	if (!(first >= 'a' && first <= 'z'))
		return "First character must be 'a-z' or 'A-Z'.";

	for (const char c : name_lower)
	{
		if (!(c == '_' || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')))
			return "Name must strictly contain characters a-z, A-Z, 0-9 and under_score.";
	}

	if (reserved_names.count(name_lower) == 1)
		return "Name is reserved.";

	return nullptr;
}

static std::string DataAddressToString(const DataAddress& address) {
	std::string result;
	bool is_first = true;
	for (auto& entry : address)
	{
		if (entry.index >= 0)
			result += '[' + ToString(entry.index) + ']';
		else
		{
			if (!is_first)
				result += ".";
			result += entry.name;
		}
		is_first = false;
	}
	return result;
}

DataModel::DataModel()
{}

DataModel::~DataModel() {
	assert(attached_elements.empty());
}

void DataModel::AddView(DataViewPtr view) {
	views_to_add.push_back(std::move(view));
}

void DataModel::AddEvent(DataEventPtr event) {
	Element* element = event->GetElement();
	if (!element)
		return;
	events.emplace(element, std::move(event));
}

bool DataModel::BindVariable(const std::string& name, DataVariable variable) {
	const char* name_error_str = LegalVariableName(name);
	if (name_error_str)
	{
		Log::Message(Log::Level::Warning, "Could not bind data variable '%s'. %s", name.c_str(), name_error_str);
		return false;
	}

	if (!variable)
	{
		Log::Message(Log::Level::Warning, "Could not bind variable '%s' to data model, data type not registered.", name.c_str());
		return false;
	}

	bool inserted = variables.emplace(name, variable).second;
	if (!inserted)
	{
		Log::Message(Log::Level::Warning, "Data model variable with name '%s' already exists.", name.c_str());
		return false;
	}

	return true;
}

bool DataModel::BindEventCallback(const std::string& name, DataEventFunc event_func) {
	const char* name_error_str = LegalVariableName(name);
	if (name_error_str)
	{
		Log::Message(Log::Level::Warning, "Could not bind data event callback '%s'. %s", name.c_str(), name_error_str);
		return false;
	}

	if (!event_func)
	{
		Log::Message(Log::Level::Warning, "Could not bind data event callback '%s' to data model, empty function provided.", name.c_str());
		return false;
	}

	bool inserted = event_callbacks.emplace(name, std::move(event_func)).second;
	if (!inserted)
	{
		Log::Message(Log::Level::Warning, "Data event callback with name '%s' already exists.", name.c_str());
		return false;
	}

	return true;
}

bool DataModel::InsertAlias(Node* element, const std::string& alias_name, DataAddress replace_with_address) {
	if (replace_with_address.empty() || replace_with_address.front().name.empty())
	{
		Log::Message(Log::Level::Warning, "Could not add alias variable '%s' to data model, replacement address invalid.", alias_name.c_str());
		return false;
	}

	if (variables.count(alias_name) == 1)
		Log::Message(Log::Level::Warning, "Alias variable '%s' is shadowed by a global variable.", alias_name.c_str());

	auto& map = aliases.emplace(element, std::unordered_map<std::string, DataAddress>()).first->second;
	
	auto it = map.find(alias_name);
	if (it != map.end())
		Log::Message(Log::Level::Warning, "Alias name '%s' in data model already exists, replaced.", alias_name.c_str());

	map[alias_name] = std::move(replace_with_address);

	return true;
}

bool DataModel::EraseAliases(Node* element) {
	return aliases.erase(element) == 1;
}

DataAddress DataModel::ResolveAddress(const std::string& address_str, Node* element) const {
	DataAddress address = ParseAddress(address_str);

	if (address.empty())
		return address;

	const std::string& first_name = address.front().name;

	auto it = variables.find(first_name);
	if (it != variables.end())
		return address;

	// Look for a variable alias for the first name.
	Node* ancestor = element;
	while (ancestor && ancestor->GetDataModel() == this)
	{
		auto it_element = aliases.find(ancestor);
		if (it_element != aliases.end())
		{
			const auto& alias_names = it_element->second;
			auto it_alias_name = alias_names.find(first_name);
			if (it_alias_name != alias_names.end())
			{
				const DataAddress& replace_address = it_alias_name->second;
				if (replace_address.empty() || replace_address.front().name.empty())
				{
					// Variable alias is invalid
					return DataAddress();
				}

				// Insert the full alias address, replacing the first element.
				address[0] = replace_address[0];
				address.insert(address.begin() + 1, replace_address.begin() + 1, replace_address.end());
				return address;
			}
		}

		ancestor = ancestor->GetParentNode();
	}

	Log::Message(Log::Level::Warning, "Could not find variable name '%s' in data model.", address_str.c_str());

	return DataAddress();
}

DataVariable DataModel::GetVariable(const DataAddress& address) const {
	if (address.empty())
		return DataVariable();

	auto it = variables.find(address.front().name);
	if (it != variables.end()) {
		DataVariable variable = it->second;

		for (int i = 1; i < (int)address.size() && variable; i++) {
			variable = variable.Child(address[i]);
			if (!variable)
				return DataVariable();
		}

		return variable;
	}

	if (address[0].name == "literal")
	{
		if (address.size() > 2 && address[1].name == "int")
			return MakeLiteralIntVariable(address[2].index);
	}

	return DataVariable();
}

const DataEventFunc* DataModel::GetEventCallback(const std::string& name) {
	auto it = event_callbacks.find(name);
	if (it == event_callbacks.end()) {
		Log::Message(Log::Level::Warning, "Could not find data event callback '%s' in data model.", name.c_str());
		return nullptr;
	}

	return &it->second;
}

bool DataModel::GetVariableInto(const DataAddress& address, Variant& out_value) const {
	DataVariable variable = GetVariable(address);
	bool result = (variable && variable.Get(out_value));
	if (!result)
		Log::Message(Log::Level::Warning, "Could not get value from data variable '%s'.", DataAddressToString(address).c_str());
	return result;
}

void DataModel::DirtyVariable(const std::string& variable_name) {
	assert(LegalVariableName(variable_name) == nullptr);
	assert(variables.count(variable_name) == 1);
	dirty_variables.emplace(variable_name);
}

bool DataModel::IsVariableDirty(const std::string& variable_name) const {
	assert(LegalVariableName(variable_name) == nullptr);
	return dirty_variables.count(variable_name) == 1;
}

void DataModel::AttachModelRootElement(Element* element) {
	attached_elements.insert(element);
}

ElementList DataModel::GetAttachedModelRootElements() const {
	return ElementList(attached_elements.begin(), attached_elements.end());
}

void DataModel::OnElementRemove(Element* element) {
	EraseAliases(element);
	events.erase(element);
	attached_elements.erase(element);
}

void DataModel::Update(bool clear_dirty_variables) {
	// View updates may result in newly added views, thus we do it recursively but with an upper limit.
	//   Without the loop, newly added views won't be updated until the next Update() call.
	std::set<DataView*> views_to_remove;
	for(int i = 0; i == 0 || (!views_to_add.empty() && i < 10); i++) {
		std::vector<DataView*> dirty_views;

		if (!views_to_add.empty()) {
			views.reserve(views.size() + views_to_add.size());
			for (auto&& view : views_to_add) {
				dirty_views.push_back(view.get());
				for (const std::string& variable_name : view->GetVariableNameList())
					name_view_map.emplace(variable_name, view.get());

				views.push_back(std::move(view));
			}
			views_to_add.clear();
		}

		for (const std::string& variable_name : dirty_variables) {
			auto pair = name_view_map.equal_range(variable_name);
			for (auto it = pair.first; it != pair.second; ++it)
				dirty_views.push_back(it->second);
		}

		// Remove duplicate entries
		std::sort(dirty_views.begin(), dirty_views.end());
		auto it_remove = std::unique(dirty_views.begin(), dirty_views.end());
		dirty_views.erase(it_remove, dirty_views.end());

		// Sort by the element's depth in the document tree so that any structural changes due to a changed variable are reflected in the element's children.
		// Eg. the 'data-for' view will remove children if any of its data variable array size is reduced.
		std::sort(dirty_views.begin(), dirty_views.end(), [](auto&& left, auto&& right) { return left->GetDepth() < right->GetDepth(); });

		for (DataView* view : dirty_views) {
			assert(view);
			if (!view)
				continue;
			if (view->IsValid())
				view->Update(*this);
			else {
				views_to_remove.insert(view);
			}
		}

		if (!views_to_remove.empty()) {
			for (auto it = views.begin(); it != views.end(); ) {
				if (views_to_remove.contains(it->get()))
					it = views.erase(it);
				else
					++it;
			}
			for (auto it = name_view_map.begin(); it != name_view_map.end(); ) {
				if (views_to_remove.contains(it->second))
					it = name_view_map.erase(it);
				else
					++it;
			}
			views_to_remove.clear();
		}
	}

	if (clear_dirty_variables)
		dirty_variables.clear();
}

}
