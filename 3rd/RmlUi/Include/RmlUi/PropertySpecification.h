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

#ifndef RMLUI_CORE_PROPERTYSPECIFICATION_H
#define RMLUI_CORE_PROPERTYSPECIFICATION_H

#include "Platform.h"
#include "Types.h"
#include "PropertyIdSet.h"
#include "ID.h"

namespace Rml {

class StyleSheetSpecification;
class PropertyDefinition;
class PropertyDictionary;
class PropertyIdNameMap;
class ShorthandIdNameMap;
struct ShorthandDefinition;

enum class ShorthandType
{
	// Normal; properties that fail to parse fall-through to the next until they parse correctly, and any
	// undeclared are not set.
	FallThrough,
	// A single failed parse will abort, and any undeclared are replicated from the last declared property.
	Replicate,
	// For 'padding', 'margin', etc; up to four properties are expected.
	Box,
	// Repeatedly resolves the full value string on each property, whether it is a normal property or another shorthand.
	RecursiveRepeat,
	// Comma-separated list of properties or shorthands, the number of declared values must match the specified.
	RecursiveCommaSeparated
};


/**
	A property specification stores a group of property definitions.

	@author Peter Curry
 */

class PropertySpecification
{
public:
	PropertySpecification();
	~PropertySpecification();

	/// Registers a property with a new definition.
	/// @param[in] property_name The name to register the new property under.
	/// @param[in] default_value The default value to be used for an element if it has no other definition provided.
	/// @param[in] inherited True if this property is inherited from parent to child, false otherwise.
	/// @param[in] id If 'Invalid' then automatically assigns a new id, otherwise assigns the given id.
	/// @return The new property definition, ready to have parsers attached.
	PropertyDefinition& RegisterProperty(PropertyId id, const std::string& property_name, bool inherited);
	PropertyDefinition& RegisterProperty(PropertyId id, const std::string& property_name, bool inherited, const std::string& default_value);
	/// Returns a property definition.
	/// @param[in] id The id of the desired property.
	/// @return The appropriate property definition if it could be found, nullptr otherwise.
	const PropertyDefinition* GetProperty(PropertyId id) const;
	const PropertyDefinition* GetProperty(const std::string& property_name) const;

	/// Returns the id set of all registered property definitions.
	const PropertyIdSet& GetRegisteredProperties() const;
	/// Returns the id set of all registered inherited property definitions.
	const PropertyIdSet& GetRegisteredInheritedProperties() const;

	/// Registers a shorthand property definition.
	/// @param[in] shorthand_name The name to register the new shorthand property under.
	/// @param[in] properties A comma-separated list of the properties this definition is shorthand for. The order in which they are specified here is the order in which the values will be processed.
	/// @param[in] type The type of shorthand to declare.
	/// @param[in] id If 'Invalid' then automatically assigns a new id, otherwise assigns the given id.
	/// @param True if all the property names exist, false otherwise.
	ShorthandId RegisterShorthand(const std::string& shorthand_name, const std::string& property_names, ShorthandType type, ShorthandId id = ShorthandId::Invalid);
	/// Returns a shorthand definition.
	/// @param[in] shorthand_name The name of the desired shorthand.
	/// @return The appropriate shorthand definition if it could be found, nullptr otherwise.
	const ShorthandDefinition* GetShorthand(ShorthandId id) const;
	const ShorthandDefinition* GetShorthand(const std::string& shorthand_name) const;

	bool ParsePropertyDeclaration(PropertyIdSet& set, const std::string& property_name) const;
	bool ParsePropertyDeclaration(PropertyDictionary& dictionary, const std::string& property_name, const std::string& property_value) const;
	bool ParsePropertyDeclaration(PropertyDictionary& dictionary, PropertyId property_id, const std::string& property_value) const;
	void ParseShorthandDeclaration(PropertyIdSet& set, ShorthandId shorthand_id) const;
	bool ParseShorthandDeclaration(PropertyDictionary& dictionary, ShorthandId shorthand_id, const std::string& property_value) const;

private:
	using Properties = std::vector< std::unique_ptr<PropertyDefinition> >;
	using Shorthands = std::vector< std::unique_ptr<ShorthandDefinition> >;

	Properties properties;
	Shorthands shorthands;

	std::unique_ptr<PropertyIdNameMap> property_map;
	std::unique_ptr<ShorthandIdNameMap> shorthand_map;

	PropertyIdSet property_ids;
	PropertyIdSet property_ids_inherited;

	bool ParsePropertyValues(std::vector<std::string>& values_list, const std::string& values, bool split_values) const;

	friend class Rml::StyleSheetSpecification;
};

} // namespace Rml
#endif
