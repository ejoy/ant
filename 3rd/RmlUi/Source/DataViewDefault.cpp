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

#include "DataViewDefault.h"
#include "DataExpression.h"
#include "DataModel.h"
#include "../Include/RmlUi/Document.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/ElementText.h"
#include "../Include/RmlUi/Variant.h"
#include "../Include/RmlUi/Log.h"
#include "../Include/RmlUi/StringUtilities.h"

namespace Rml {

DataViewCommon::DataViewCommon(Element* element, std::string override_modifier)
	: DataView(element)
	, modifier(std::move(override_modifier))
{}

bool DataViewCommon::Initialize(DataModel& model, Element* element, const std::string& expression_str, const std::string& in_modifier) {
	// The modifier can be overriden in the constructor
	if (modifier.empty())
		modifier = in_modifier;

	expression = std::make_unique<DataExpression>(expression_str);
	DataExpressionInterface expr_interface(&model, element);

	bool result = expression->Parse(expr_interface, false);
	return result;
}

std::vector<std::string> DataViewCommon::GetVariableNameList() const {
	assert(expression);
	return expression->GetVariableNameList();
}

const std::string& DataViewCommon::GetModifier() const {
	return modifier;
}

DataExpression& DataViewCommon::GetExpression() {
	assert(expression);
	return *expression;
}

DataViewStyle::DataViewStyle(Element* element)
	: DataViewCommon(element)
{}

bool DataViewStyle::Update(DataModel& model) {
	const std::string& property_name = GetModifier();
	bool result = false;
	Variant variant;
	Element* element = GetElement();
	DataExpressionInterface expr_interface(&model, element);
	
	if (element && GetExpression().Run(expr_interface, variant)) {
		std::optional<std::string> newValue = VariantHelper::ToStringOpt(variant);
		std::optional<std::string> oldValue = element->GetProperty(property_name);
		if (newValue != oldValue) {
			element->SetProperty(property_name, newValue);
			result = true;
		}
	}
	return result;
}

DataViewIf::DataViewIf(Element* element)
	: DataViewCommon(element)
{}

bool DataViewIf::Update(DataModel& model) {
	bool result = false;
	Variant variant;
	Element* element = GetElement();
	DataExpressionInterface expr_interface(&model, element);

	if (element && GetExpression().Run(expr_interface, variant))
	{
		const bool value = VariantHelper::Get<bool>(variant);
		// fixed nested data-if for same variant bug
		//if (element->IsVisible() != value) {
			element->SetVisible(value);
			result = true;
		//}
	}
	return result;
}

DataViewText::DataViewText(Element* element) : DataView(element)
{}

bool DataViewText::Initialize(DataModel& model, Element* element, const std::string&, const std::string&) {
	ElementText* element_text = dynamic_cast<ElementText*>(element);
	if (!element_text)
		return false;

	const std::string& in_text = element_text->GetText();
	
	text.reserve(in_text.size());

	DataExpressionInterface expression_interface(&model, element);

	size_t previous_close_brackets = 0;
	size_t begin_brackets = 0;
	while ((begin_brackets = in_text.find("{{", begin_brackets)) != std::string::npos) {
		text.insert(text.end(), in_text.begin() + previous_close_brackets, in_text.begin() + begin_brackets);

		const size_t begin_name = begin_brackets + 2;
		const size_t end_name = in_text.find("}}", begin_name);

		if (end_name == std::string::npos)
			return false;

		DataEntry entry;
		entry.index = text.size();
		entry.data_expression = std::make_unique<DataExpression>(std::string(in_text.begin() + begin_name, in_text.begin() + end_name));

		if (entry.data_expression->Parse(expression_interface, false))
			data_entries.push_back(std::move(entry));

		previous_close_brackets = end_name + 2;
		begin_brackets = previous_close_brackets;
	}

	if (data_entries.empty())
		return false;

	if (previous_close_brackets < in_text.size())
		text.insert(text.end(), in_text.begin() + previous_close_brackets, in_text.end());

	return true;
}

bool DataViewText::Update(DataModel& model) {
	bool entries_modified = false;
	{
		Element* element = GetElement();
		DataExpressionInterface expression_interface(&model, element);

		for (DataEntry& entry : data_entries) {
			assert(entry.data_expression);
			Variant variant;
			bool result = entry.data_expression->Run(expression_interface, variant);
			const std::string value = VariantHelper::ToString(variant);
			if (result && entry.value != value) {
				entry.value = value;
				entries_modified = true;
			}
		}
	}

	if (entries_modified) {
		if (Element* element = GetElement()) {
			assert(dynamic_cast<ElementText*>(element));

			if (ElementText* text_element = static_cast<ElementText*>(element)) {
				std::string new_text = BuildText();
				text_element->SetText(new_text);
			}
		}
		else {
			Log::Message(Log::Level::Warning, "Could not update data view text, element no longer valid. Was it destroyed?");
		}
	}

	return entries_modified;
}

std::vector<std::string> DataViewText::GetVariableNameList() const {
	std::vector<std::string> full_list;
	full_list.reserve(data_entries.size());

	for (const DataEntry& entry : data_entries) {
		assert(entry.data_expression);

		std::vector<std::string> entry_list = entry.data_expression->GetVariableNameList();
		full_list.insert(full_list.end(),
			std::make_move_iterator(entry_list.begin()),
			std::make_move_iterator(entry_list.end())
		);
	}

	return full_list;
}

std::string DataViewText::BuildText() const {
	size_t reserve_size = text.size();

	for (const DataEntry& entry : data_entries)
		reserve_size += entry.value.size();

	std::string result;
	result.reserve(reserve_size);

	size_t previous_index = 0;
	for (const DataEntry& entry : data_entries) {
		result += text.substr(previous_index, entry.index - previous_index);
		result += entry.value;
		previous_index = entry.index;
	}

	if (previous_index < text.size())
		result += text.substr(previous_index);

	return result;
}

DataViewFor::DataViewFor(Element* element)
	: DataView(element)
{}

bool DataViewFor::Initialize(DataModel& model, Element* element, const std::string& in_expression, const std::string&) {
	std::vector<std::string> iterator_container_pair;
	StringUtilities::ExpandString(iterator_container_pair, in_expression, ':');

	if (iterator_container_pair.empty() || iterator_container_pair.size() > 2 || iterator_container_pair.front().empty() || iterator_container_pair.back().empty()) {
		Log::Message(Log::Level::Warning, "Invalid syntax in data-for '%s'", in_expression.c_str());
		return false;
	}

	if (iterator_container_pair.size() == 2) {
		std::vector<std::string> iterator_index_pair;
		StringUtilities::ExpandString(iterator_index_pair, iterator_container_pair.front(), ',');
		if (iterator_index_pair.empty()) {
			Log::Message(Log::Level::Warning, "Invalid syntax in data-for '%s'", in_expression.c_str());
			return false;
		}
		else if (iterator_index_pair.size() == 1) {
			iterator_name = iterator_index_pair.front();
		}
		else if (iterator_index_pair.size() == 2) {
			iterator_name = iterator_index_pair.front();
			iterator_index_name = iterator_index_pair.back();
		}
	}

	if (iterator_name.empty())
		iterator_name = "it";
	if (iterator_index_name.empty())
		iterator_index_name = "it_index";
	const std::string& container_name = iterator_container_pair.back();
	container_address = model.ResolveAddress(container_name, element);
	if (container_address.empty())
		return false;
	element->SetVisible(false);
	element->RemoveAttribute("data-for");
	return true;
}


bool DataViewFor::Update(DataModel& model) {
	DataVariable variable = model.GetVariable(container_address);
	if (!variable)
		return false;

	size_t size = (size_t)variable.Size();
	Element* element = GetElement();

	for (size_t i = num_elements; i < size; ++i) {
		DataAddress iterator_address;
		iterator_address.reserve(container_address.size() + 1);
		iterator_address = container_address;
		iterator_address.push_back(DataAddressEntry((int)i));
		DataAddress iterator_index_address = {
			{"literal"}, {"int"}, {(int)i}
		};
		ElementPtr sibling = element->Clone();
		model.InsertAlias(sibling.get(), iterator_name, std::move(iterator_address));
		model.InsertAlias(sibling.get(), iterator_index_name, std::move(iterator_index_address));
		element->GetParentNode()->InsertBefore(std::move(sibling), element);
	}
	for (size_t i = size; i < num_elements; ++i) {
		Element* sibling = element->GetPreviousSibling();
		model.EraseAliases(sibling);
		element->GetParentNode()->RemoveChild(sibling);
	}
	num_elements = size;
	return true;
}

std::vector<std::string> DataViewFor::GetVariableNameList() const {
	assert(!container_address.empty());
	return std::vector<std::string>{ container_address.front().name };
}

}
