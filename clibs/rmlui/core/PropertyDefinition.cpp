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

#include "core/PropertyDefinition.h"
#include "core/Log.h"
#include "core/StyleSheetSpecification.h"
#include "core/StringUtilities.h"

namespace Rml {

PropertyDefinition::PropertyDefinition(PropertyId id, bool inherited) 
	: id(id)
	, unparsed_default()
	, inherited(inherited)
{ }

PropertyDefinition::PropertyDefinition(PropertyId id, const std::string& unparsed_default, bool inherited) 
	: id(id)
	, unparsed_default(unparsed_default)
	, inherited(inherited)
{ }

PropertyDefinition& PropertyDefinition::AddParser(const std::string& parser_name) {
	PropertyParser* new_parser = StyleSheetSpecification::GetParser(parser_name);
	if (new_parser == nullptr) {
		Log::Message(Log::Level::Error, "Property was registered with invalid parser '%s'.", parser_name.c_str());
		return *this;
	}
	parsers.push_back(new_parser);
	if (!default_value && unparsed_default) {
		default_value = new_parser->ParseValue(unparsed_default.value());
	}
	return *this;
}

PropertyDefinition& PropertyDefinition::AddParser(const std::string& parser_name, const std::string& parser_parameters) {
	assert(parser_name == "keyword");

	PropertyParser* new_parser = StyleSheetSpecification::GetKeywordParser(parser_parameters);
	if (new_parser == nullptr) {
		Log::Message(Log::Level::Error, "Property was registered with invalid parser '%s'.", parser_name.c_str());
		return *this;
	}
	parsers.push_back(new_parser);
	if (!default_value && unparsed_default) {
		default_value = new_parser->ParseValue(unparsed_default.value());
	}
	return *this;
}

std::optional<Property> PropertyDefinition::ParseValue(const std::string& value) const {
	for (auto parser : parsers) {
		auto property = parser->ParseValue(value);
		if (property) {
			return std::move(property);
		}
	}
	return std::nullopt;

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
