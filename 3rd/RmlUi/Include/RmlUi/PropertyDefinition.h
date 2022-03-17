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

#ifndef RMLUI_CORE_PROPERTYDEFINITION_H
#define RMLUI_CORE_PROPERTYDEFINITION_H

#include "Property.h"
#include "PropertyParser.h"
#include <optional>

namespace Rml {

/**
	@author Peter Curry
 */

class PropertyDefinition final
{
public:
	PropertyDefinition(PropertyId id, bool inherited);
	PropertyDefinition(PropertyId id, const std::string& default_value, bool inherited);
	PropertyDefinition(const PropertyDefinition &) = delete; 
	PropertyDefinition& operator=(const PropertyDefinition &) = delete;
	~PropertyDefinition();

	/// Registers a parser to parse values for this definition.
	/// @param[in] parser_name The name of the parser (default parsers are 'string', 'keyword', 'number' and 'colour').
	/// @param[in] parser_parameters A comma-separated list of validation parameters for the parser.
	/// @return This property definition.
	PropertyDefinition& AddParser(const std::string& parser_name, const std::string& parser_parameters = "");


	/// Called when parsing a RCSS declaration.
	/// @param property[out] The property to set the parsed value onto.
	/// @param value[in] The raw value defined for this property.
	/// @return True if all values were parsed successfully, false otherwise.
	bool ParseValue(Property& property, const std::string& value) const;

	/// Returns true if this property is inherited from parent to child elements.
	bool IsInherited() const;

	/// Returns the default defined for this property.
	const Property* GetDefaultValue() const;

	/// Return the property id
	PropertyId GetId() const;

private:
	PropertyId id;
	std::optional<Property> default_value;
	bool inherited;
	struct ParserState {
		PropertyParser* parser;
		ParameterMap parameters;
	};
	std::vector< ParserState > parsers;
};

}
#endif
