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

#include "../Include/RmlUi/PropertyDefinition.h"
#include "../Include/RmlUi/Log.h"
#include "../Include/RmlUi/StyleSheetSpecification.h"
#include "../Include/RmlUi/StringUtilities.h"

namespace Rml {

PropertyDefinition::PropertyDefinition(PropertyId id, bool inherited) 
	: id(id)
	, inherited(inherited)
{ }

PropertyDefinition::PropertyDefinition(PropertyId id, const std::string& unparsed_default, bool inherited) 
	: id(id)
	, unparsed_default(unparsed_default)
	, inherited(inherited)
{ }

PropertyDefinition::~PropertyDefinition()
{ }

PropertyDefinition& PropertyDefinition::AddParser(const std::string& parser_name, const std::string& parser_parameters) {
	ParserState new_parser;

	new_parser.parser = StyleSheetSpecification::GetParser(parser_name);
	if (new_parser.parser == nullptr) {
		Log::Message(Log::Level::Error, "Property was registered with invalid parser '%s'.", parser_name.c_str());
		return *this;
	}

	if (!parser_parameters.empty()) {
		std::vector<std::string> parameter_list;
		StringUtilities::ExpandString(parameter_list, StringUtilities::ToLower(parser_parameters), ',');
		for (size_t i = 0; i < parameter_list.size(); i++)
			new_parser.parameters[parameter_list[i]] = (int) i;
	}
	parsers.push_back(new_parser);

	if (!default_value && !unparsed_default.empty()) {
		default_value = new_parser.parser->ParseValue(unparsed_default, new_parser.parameters);
	}

	return *this;
}

std::optional<Property> PropertyDefinition::ParseValue(const std::string& value) const {
	for (size_t i = 0; i < parsers.size(); i++) {
		auto property = parsers[i].parser->ParseValue(value, parsers[i].parameters);
		if (property) {
			return std::move(property);
		}
	}
	return {};

}

bool PropertyDefinition::IsInherited() const {
	return inherited;
}

const std::optional<Property>& PropertyDefinition::GetDefaultValue() const {
	return default_value;
}

PropertyId PropertyDefinition::GetId() const {
	return id;
}

}
