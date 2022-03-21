#include "../Include/RmlUi/StyleSheetSpecification.h"
#include "../Include/RmlUi/PropertyIdSet.h"
#include "../Include/RmlUi/PropertyDefinition.h"
#include "../Include/RmlUi/Log.h"
#include "../Include/RmlUi/StringUtilities.h"
#include "PropertyParserNumber.h"
#include "PropertyParserAnimation.h"
#include "PropertyParserColour.h"
#include "PropertyParserKeyword.h"
#include "PropertyParserString.h"
#include "PropertyParserTransform.h"
#include "PropertyShorthandDefinition.h"

namespace Rml {

class StyleSheetSpecification;
class PropertyDefinition;
struct ShorthandDefinition;

enum class ShorthandType {
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

struct StyleSheetSpecificationInstance {
	~StyleSheetSpecificationInstance();
	PropertyDefinition& RegisterProperty(PropertyId id, const std::string& property_name, bool inherited);
	PropertyDefinition& RegisterProperty(PropertyId id, const std::string& property_name, const std::string& default_value, bool inherited);
	ShorthandId RegisterShorthand(ShorthandId id, const std::string& shorthand_name, const std::string& property_names, ShorthandType type);
	void RegisterProperties();

	const PropertyDefinition* GetPropertyDefinition(PropertyId id) const;
	const PropertyIdSet& GetRegisteredInheritedProperties() const;
	const ShorthandDefinition* GetShorthandDefinition(ShorthandId id) const;
	bool ParsePropertyDeclaration(PropertyIdSet& set, const std::string& property_name) const;
	bool ParsePropertyDeclaration(PropertyDictionary& dictionary, const std::string& property_name, const std::string& property_value) const;
	bool ParsePropertyDeclaration(PropertyDictionary& dictionary, PropertyId property_id, const std::string& property_value) const;
	void ParseShorthandDeclaration(PropertyIdSet& set, ShorthandId shorthand_id) const;
	bool ParseShorthandDeclaration(PropertyDictionary& dictionary, ShorthandId shorthand_id, const std::string& property_value) const;
	bool ParsePropertyValues(std::vector<std::string>& values_list, const std::string& values, bool split_values) const;

	std::unordered_map<std::string, PropertyParser*> parsers = {
		{"number", new PropertyParserNumber(Property::UnitMark::Number)},
		{"length", new PropertyParserNumber(Property::UnitMark::Length, Property::Unit::PX)},
		{"length_percent", new PropertyParserNumber(Property::UnitMark::LengthPercent, Property::Unit::PX)},
		{"number_length_percent", new PropertyParserNumber(Property::UnitMark::NumberLengthPercent, Property::Unit::PX)},
		{"angle", new PropertyParserNumber(Property::UnitMark::Angle, Property::Unit::RAD)},
		{"keyword", new PropertyParserKeyword()},
		{"string", new PropertyParserString()},
		{"animation", new PropertyParserAnimation(PropertyParserAnimation::ANIMATION_PARSER)},
		{"transition", new PropertyParserAnimation(PropertyParserAnimation::TRANSITION_PARSER)},
		{"color", new PropertyParserColour()},
		{"transform", new PropertyParserTransform()},
	};
	std::array<std::unique_ptr<PropertyDefinition>,  (size_t)PropertyId::NumDefinedIds>  properties;
	std::array<std::unique_ptr<ShorthandDefinition>, (size_t)ShorthandId::NumDefinedIds> shorthands;
	std::unordered_map<std::string, PropertyId> property_map;
	std::unordered_map<std::string, ShorthandId> shorthand_map;
	PropertyIdSet property_ids_inherited;
};

static std::string convert(const std::string& s) {
	std::string r;
	auto f = s.find_first_not_of('-', 0);
	auto l = s.find_first_of('-', f);
	while (std::string::npos != f || std::string::npos != l) {
		auto ss = s.substr(f, l - f);
		if (!ss.empty()) {
			if (!r.empty()) {
				ss[0] = std::toupper(ss[0]);
			}
			r += ss;
		}
		f = s.find_first_not_of('-', l);
		l = s.find_first_of('-', f);
	}
	return r;
}

template <typename T>
void MapAdd(std::unordered_map<std::string, T>& map, const std::string& name, T id) {
	map.emplace(name, id);
	map.emplace(convert(name), id);
}

template <typename T>
T MapGet(std::unordered_map<std::string, T> const& map, const std::string& name)  {
	auto it = map.find(name);
	if (it != map.end())
		return it->second;
	return T::Invalid;
}

StyleSheetSpecificationInstance::~StyleSheetSpecificationInstance() {
	for (auto [_, parser] : parsers) {
		delete parser;
	}
}

PropertyDefinition& StyleSheetSpecificationInstance::RegisterProperty(PropertyId id, const std::string& property_name, const std::string& default_value, bool inherited) {
	assert (id < PropertyId::NumDefinedIds);
	MapAdd(property_map, property_name, id);
	size_t index = (size_t)id;
	if (properties[index]) {
		Log::Message(Log::Level::Error, "While registering property '%s': The property is already registered.", property_name.c_str());
		return *properties[index];
	}
	properties[index] = std::make_unique<PropertyDefinition>(id, default_value, inherited);
	if (inherited)
		property_ids_inherited.Insert(id);
	return *properties[index];
}

PropertyDefinition& StyleSheetSpecificationInstance::RegisterProperty(PropertyId id, const std::string& property_name, bool inherited) {
	assert (id < PropertyId::NumDefinedIds);
	MapAdd(property_map, property_name, id);
	size_t index = (size_t)id;
	if (properties[index]) {
		Log::Message(Log::Level::Error, "While registering property '%s': The property is already registered.", property_name.c_str());
		return *properties[index];
	}
	properties[index] = std::make_unique<PropertyDefinition>(id, inherited);
	if (inherited)
		property_ids_inherited.Insert(id);
	return *properties[index];
}

const PropertyDefinition* StyleSheetSpecificationInstance::GetPropertyDefinition(PropertyId id) const {
	if (id >= PropertyId::NumDefinedIds)
		return nullptr;
	return properties[(size_t)id].get();
}

const PropertyIdSet& StyleSheetSpecificationInstance::GetRegisteredInheritedProperties(void) const {
	return property_ids_inherited;
}

ShorthandId StyleSheetSpecificationInstance::RegisterShorthand(ShorthandId id, const std::string& shorthand_name, const std::string& property_names, ShorthandType type) {
	assert (id < ShorthandId::NumDefinedIds);
	MapAdd(shorthand_map, shorthand_name, id);

	std::vector<std::string> property_list;
	StringUtilities::ExpandString(property_list, StringUtilities::ToLower(property_names));

	std::unique_ptr<ShorthandDefinition> property_shorthand(new ShorthandDefinition());

	for (const std::string& raw_name : property_list) {
		ShorthandItem item;
		bool optional = false;
		std::string name = raw_name;

		if (!raw_name.empty() && raw_name.back() == '?') {
			optional = true;
			name.pop_back();
		}

		PropertyId property_id = MapGet(property_map, name);
		if (property_id != PropertyId::Invalid) {
			// We have a valid property
			if (const PropertyDefinition* property = GetPropertyDefinition(property_id))
				item = ShorthandItem(property_id, property, optional);
		}
		else {
			// Otherwise, we must be a shorthand
			ShorthandId shorthand_id = MapGet(shorthand_map, name);

			// Test for valid shorthand id. The recursive types (and only those) can hold other shorthands.
			if (shorthand_id != ShorthandId::Invalid && (type == ShorthandType::RecursiveRepeat || type == ShorthandType::RecursiveCommaSeparated)) {
				if (const ShorthandDefinition * shorthand = GetShorthandDefinition(shorthand_id))
					item = ShorthandItem(shorthand_id, shorthand, optional);
			}
		}

		if (item.type == ShorthandItemType::Invalid) {
			Log::Message(Log::Level::Error, "Shorthand property '%s' was registered with invalid property '%s'.", shorthand_name.c_str(), name.c_str());
			return ShorthandId::Invalid;
		}
		property_shorthand->items.push_back(item);
	}

	property_shorthand->id = id;
	property_shorthand->type = type;

	const size_t index = (size_t)id;
	// We don't want to owerwrite an existing entry.
	if (shorthands[index]) {
		Log::Message(Log::Level::Error, "The shorthand '%s' already exists, ignoring.", shorthand_name.c_str());
		return ShorthandId::Invalid;
	}
	shorthands[index] = std::move(property_shorthand);
	return id;
}

const ShorthandDefinition* StyleSheetSpecificationInstance::GetShorthandDefinition(ShorthandId id) const {
	if (id >= ShorthandId::NumDefinedIds)
		return nullptr;
	return shorthands[(size_t)id].get();
}

void StyleSheetSpecificationInstance::ParseShorthandDeclaration(PropertyIdSet& set, ShorthandId shorthand_id) const {
	const ShorthandDefinition* shorthand_definition = GetShorthandDefinition(shorthand_id);
	for (size_t i = 0; i < shorthand_definition->items.size(); ++i) {
		const ShorthandItem& item = shorthand_definition->items[i];
		if (item.type == ShorthandItemType::Property)
			set.Insert(item.property_id);
		else if (item.type == ShorthandItemType::Shorthand)
			ParseShorthandDeclaration(set, item.shorthand_id);
	}
}

bool StyleSheetSpecificationInstance::ParsePropertyDeclaration(PropertyIdSet& set, const std::string& property_name) const {
	// Try as a property first
	PropertyId property_id = MapGet(property_map, property_name);
	if (property_id != PropertyId::Invalid) {
		set.Insert(property_id);
		return true;
	}

	// Then, as a shorthand
	ShorthandId shorthand_id = MapGet(shorthand_map, property_name);
	if (shorthand_id != ShorthandId::Invalid) {
		ParseShorthandDeclaration(set, shorthand_id);
		return true;
	}
	return false;
}

bool StyleSheetSpecificationInstance::ParsePropertyDeclaration(PropertyDictionary& dictionary, const std::string& property_name, const std::string& property_value) const {
	// Try as a property first
	PropertyId property_id = MapGet(property_map, property_name);
	if (property_id != PropertyId::Invalid) {
		if (ParsePropertyDeclaration(dictionary, property_id, property_value)) {
			return true;
		}
	}

	// Then, as a shorthand
	ShorthandId shorthand_id = MapGet(shorthand_map, property_name);
	if (shorthand_id != ShorthandId::Invalid) {
		if (ParseShorthandDeclaration(dictionary, shorthand_id, property_value)){
			return true;
		}
	}

	return false;
}

bool StyleSheetSpecificationInstance::ParsePropertyDeclaration(PropertyDictionary& dictionary, PropertyId property_id, const std::string& property_value) const {
	// Parse as a single property.
	const PropertyDefinition* property_definition = GetPropertyDefinition(property_id);
	if (!property_definition)
		return false;

	std::vector<std::string> property_values;
	if (!ParsePropertyValues(property_values, property_value, false) || property_values.size() == 0)
		return false;

	Property new_property;
	if (!property_definition->ParseValue(new_property, property_values[0]))
		return false;
	
	dictionary[property_id] = new_property;
	return true;
}

// Parses a property declaration, setting any parsed and validated properties on the given dictionary.
bool StyleSheetSpecificationInstance::ParseShorthandDeclaration(PropertyDictionary& dictionary, ShorthandId shorthand_id, const std::string& property_value) const {
	std::vector<std::string> property_values;
	if (!ParsePropertyValues(property_values, property_value, true) || property_values.size() == 0)
		return false;

	// Parse as a shorthand.
	const ShorthandDefinition* shorthand_definition = GetShorthandDefinition(shorthand_id);
	if (!shorthand_definition)
		return false;

	// If this definition is a 'box'-style shorthand (x-top, x-right, x-bottom, x-left, etc) and there are fewer
	// than four values
	if (shorthand_definition->type == ShorthandType::Box && property_values.size() < 4) {
		// This array tells which property index each side is parsed from
		std::array<int, 4> box_side_to_value_index = { 0,0,0,0 };
		switch (property_values.size()) {
		case 1:
			// Only one value is defined, so it is parsed onto all four sides.
			box_side_to_value_index = { 0,0,0,0 };
			break;
		case 2:
			// Two values are defined, so the first one is parsed onto the top and bottom value, the second onto
			// the left and right.
			box_side_to_value_index = { 0,1,0,1 };
			break;
		case 3:
			// Three values are defined, so the first is parsed into the top value, the second onto the left and
			// right, and the third onto the bottom.
			box_side_to_value_index = { 0,1,2,1 };
			break;
		default:
			assert(false);
			break;
		}

		for (int i = 0; i < 4; i++) {
			assert(shorthand_definition->items[i].type == ShorthandItemType::Property);
			Property new_property;
			int value_index = box_side_to_value_index[i];
			if (!shorthand_definition->items[i].property_definition->ParseValue(new_property, property_values[value_index]))
				return false;

			dictionary[shorthand_definition->items[i].property_definition->GetId()] = new_property;
		}
	}
	else if (shorthand_definition->type == ShorthandType::RecursiveRepeat) {
		bool result = true;

		for (size_t i = 0; i < shorthand_definition->items.size(); i++) {
			const ShorthandItem& item = shorthand_definition->items[i];
			if (item.type == ShorthandItemType::Property)
				result &= ParsePropertyDeclaration(dictionary, item.property_id, property_value);
			else if (item.type == ShorthandItemType::Shorthand)
				result &= ParseShorthandDeclaration(dictionary, item.shorthand_id, property_value);
			else
				result = false;
		}

		if (!result)
			return false;
	}
	else if (shorthand_definition->type == ShorthandType::RecursiveCommaSeparated) {
		std::vector<std::string> subvalues;
		StringUtilities::ExpandString(subvalues, property_value);

		size_t num_optional = 0;
		for (auto& item : shorthand_definition->items)
			if (item.optional)
				num_optional += 1;

		if (subvalues.size() + num_optional < shorthand_definition->items.size()) {
			// Not enough subvalues declared.
			return false;
		}

		size_t subvalue_i = 0;
		for (size_t i = 0; i < shorthand_definition->items.size() && subvalue_i < subvalues.size(); i++) {
			bool result = false;

			const ShorthandItem& item = shorthand_definition->items[i];
			if (item.type == ShorthandItemType::Property)
				result = ParsePropertyDeclaration(dictionary, item.property_id, subvalues[subvalue_i]);
			else if (item.type == ShorthandItemType::Shorthand)
				result = ParseShorthandDeclaration(dictionary, item.shorthand_id, subvalues[subvalue_i]);

			if (result)
				subvalue_i += 1;
			else if (!item.optional)
				return false;
		}
	}
	else {
		size_t value_index = 0;
		size_t property_index = 0;

		for (; value_index < property_values.size() && property_index < shorthand_definition->items.size(); property_index++) {
			Property new_property;

			if (!shorthand_definition->items[property_index].property_definition->ParseValue(new_property, property_values[value_index])) {
				// This definition failed to parse; if we're falling through, try the next property. If there is no
				// next property, then abort!
				if (shorthand_definition->type == ShorthandType::FallThrough) {
					if (property_index + 1 < shorthand_definition->items.size())
						continue;
				}
				return false;
			}

			dictionary[shorthand_definition->items[property_index].property_id] = new_property;

			// Increment the value index, unless we're replicating the last value and we're up to the last value.
			if (shorthand_definition->type != ShorthandType::Replicate ||
				value_index < property_values.size() - 1)
				value_index++;
		}
	}

	return true;
}

bool StyleSheetSpecificationInstance::ParsePropertyValues(std::vector<std::string>& values_list, const std::string& values, bool split_values) const {
	std::string value;

	enum ParseState { VALUE, VALUE_PARENTHESIS, VALUE_QUOTE };
	ParseState state = VALUE;
	int open_parentheses = 0;

	size_t character_index = 0;
	char previous_character = 0;
	while (character_index < values.size()) {
		char character = values[character_index];
		character_index++;

		switch (state) {
			case VALUE: {
				if (character == ';') {
					value = StringUtilities::StripWhitespace(value);
					if (value.size() > 0) {
						values_list.push_back(value);
						value.clear();
					}
				}
				else if (StringUtilities::IsWhitespace(character)) {
					if (split_values) {
						value = StringUtilities::StripWhitespace(value);
						if (value.size() > 0) {
							values_list.push_back(value);
							value.clear();
						}
					}
					else
						value += character;
				}
				else if (character == '"') {
					if (split_values) {
						value = StringUtilities::StripWhitespace(value);
						if (value.size() > 0) {
							values_list.push_back(value);
							value.clear();
						}
						state = VALUE_QUOTE;
					}
					else {
						value += ' ';
						state = VALUE_QUOTE;
					}
				}
				else if (character == '(') {
					open_parentheses = 1;
					value += character;
					state = VALUE_PARENTHESIS;
				}
				else {
					value += character;
				}
			}
			break;

			case VALUE_PARENTHESIS: {
				if (previous_character == '/') {
					if (character == ')' || character == '(')
						value += character;
					else {
						value += '/';
						value += character;
					}
				}
				else {
					if (character == '(') {
						open_parentheses++;
						value += character;
					}
					else if (character == ')') {
						open_parentheses--;
						value += character;
						if (open_parentheses == 0)
							state = VALUE;
					}
					else if (character != '/') {
						value += character;
					}
				}
			}
			break;

			case VALUE_QUOTE: {
				if (previous_character == '/') {
					if (character == '"')
						value += character;
					else {
						value += '/';
						value += character;
					}
				}
				else {
					if (character == '"') {
						if (split_values) {
							value = StringUtilities::StripWhitespace(value);
							if (value.size() > 0) {
								values_list.push_back(value);
								value.clear();
							}
						}
						else
							value += ' ';
						state = VALUE;
					}
					else if (character != '/') {
						value += character;
					}
				}
			}
		}

		previous_character = character;
	}

	if (state == VALUE) {
		value = StringUtilities::StripWhitespace(value);
		if (value.size() > 0)
			values_list.push_back(value);
	}

	return true;
}

void StyleSheetSpecificationInstance::RegisterProperties() {
	RegisterProperty(PropertyId::BorderTopWidth, "border-top-width", "0px", false)
		.AddParser("length");
	RegisterProperty(PropertyId::BorderRightWidth, "border-right-width", "0px", false)
		.AddParser("length");
	RegisterProperty(PropertyId::BorderBottomWidth, "border-bottom-width", "0px", false)
		.AddParser("length");
	RegisterProperty(PropertyId::BorderLeftWidth, "border-left-width", "0px", false)
		.AddParser("length");
	RegisterShorthand(ShorthandId::BorderWidth, "border-width", "border-top-width, border-right-width, border-bottom-width, border-left-width", ShorthandType::Box);

	RegisterProperty(PropertyId::BorderTopColor, "border-top-color", "black", false)
		.AddParser("color");
	RegisterProperty(PropertyId::BorderRightColor, "border-right-color", "black", false)
		.AddParser("color");
	RegisterProperty(PropertyId::BorderBottomColor, "border-bottom-color", "black", false)
		.AddParser("color");
	RegisterProperty(PropertyId::BorderLeftColor, "border-left-color", "black", false)
		.AddParser("color");
	RegisterShorthand(ShorthandId::BorderColor, "border-color", "border-top-color, border-right-color, border-bottom-color, border-left-color", ShorthandType::Box);

	RegisterShorthand(ShorthandId::BorderTop, "border-top", "border-top-width, border-top-color", ShorthandType::FallThrough);
	RegisterShorthand(ShorthandId::BorderRight, "border-right", "border-right-width, border-right-color", ShorthandType::FallThrough);
	RegisterShorthand(ShorthandId::BorderBottom, "border-bottom", "border-bottom-width, border-bottom-color", ShorthandType::FallThrough);
	RegisterShorthand(ShorthandId::BorderLeft, "border-left", "border-left-width, border-left-color", ShorthandType::FallThrough);
	RegisterShorthand(ShorthandId::Border, "border", "border-top, border-right, border-bottom, border-left", ShorthandType::RecursiveRepeat);

	RegisterProperty(PropertyId::BorderTopLeftRadius, "border-top-left-radius", "0px", false)
		.AddParser("length_percent");
	RegisterProperty(PropertyId::BorderTopRightRadius, "border-top-right-radius", "0px", false)
		.AddParser("length_percent");
	RegisterProperty(PropertyId::BorderBottomRightRadius, "border-bottom-right-radius", "0px", false)
		.AddParser("length_percent");
	RegisterProperty(PropertyId::BorderBottomLeftRadius, "border-bottom-left-radius", "0px", false)
		.AddParser("length_percent");
	RegisterShorthand(ShorthandId::BorderRadius, "border-radius", "border-top-left-radius, border-top-right-radius, border-bottom-right-radius, border-bottom-left-radius", ShorthandType::Box);

	RegisterProperty(PropertyId::ZIndex, "z-index", "auto", false)
		.AddParser("keyword", "auto")
		.AddParser("number");

	RegisterProperty(PropertyId::LineHeight, "line-height", "1.2", true)
		.AddParser("number");

	RegisterProperty(PropertyId::Color, "color", "white", true)
		.AddParser("color");

	RegisterProperty(PropertyId::Opacity, "opacity", "1", true)
		.AddParser("number");

	RegisterProperty(PropertyId::FontFamily, "font-family", "", true)
		.AddParser("string");
	RegisterProperty(PropertyId::FontStyle, "font-style", "normal", true)
		.AddParser("keyword", "normal, italic");
	RegisterProperty(PropertyId::FontWeight, "font-weight", "normal", true)
		.AddParser("keyword", "normal, bold");
	RegisterProperty(PropertyId::FontSize, "font-size", "12px", true)
		.AddParser("length")
		.AddParser("length_percent");
	RegisterShorthand(ShorthandId::Font, "font", "font-style, font-weight, font-size, font-family", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::TextAlign, "text-align", "left", true)
		.AddParser("keyword", "left, right, center, justify");
	RegisterProperty(PropertyId::TextTransform, "text-transform", "none", true)
		.AddParser("keyword", "none, capitalize, uppercase, lowercase");
	RegisterProperty(PropertyId::WhiteSpace, "white-space", "normal", true)
		.AddParser("keyword", "normal, pre, nowrap, pre-wrap, pre-line");
	RegisterProperty(PropertyId::WordBreak, "word-break", "normal", true)
		.AddParser("keyword", "normal, break-all, break-word");

	RegisterProperty(PropertyId::TextDecorationLine, "text-decoration-line", "none", true)
		.AddParser("keyword", "none, underline, overline, line-through");
	RegisterProperty(PropertyId::TextDecorationColor, "text-decoration-color", "currentColor", true)
		.AddParser("keyword", "currentColor")
		.AddParser("color");
	RegisterShorthand(ShorthandId::TextDecoration, "text-decoration", "text-decoration-line, text-decoration-color", ShorthandType::FallThrough);
	
	// Perspective and Transform specifications
	RegisterProperty(PropertyId::Perspective, "perspective", "none", false)
		.AddParser("keyword", "none").AddParser("length");
	RegisterProperty(PropertyId::PerspectiveOriginX, "perspective-origin-x", "50%", false)
		.AddParser("keyword", "left, center, right")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::PerspectiveOriginY, "perspective-origin-y", "50%", false)
		.AddParser("keyword", "top, center, bottom")
		.AddParser("length_percent");
	RegisterShorthand(ShorthandId::PerspectiveOrigin, "perspective-origin", "perspective-origin-x, perspective-origin-y", ShorthandType::FallThrough);
	RegisterProperty(PropertyId::Transform, "transform", "none", false)
		.AddParser("transform");
	RegisterProperty(PropertyId::TransformOriginX, "transform-origin-x", "50%", false)
		.AddParser("keyword", "left, center, right")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::TransformOriginY, "transform-origin-y", "50%", false)
		.AddParser("keyword", "top, center, bottom")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::TransformOriginZ, "transform-origin-z", "0", false)
		.AddParser("length");
	RegisterShorthand(ShorthandId::TransformOrigin, "transform-origin", "transform-origin-x, transform-origin-y, transform-origin-z", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::Transition, "transition", "none", false)
		.AddParser("transition");
	RegisterProperty(PropertyId::Animation, "animation", "none", false)
		.AddParser("animation");

	RegisterProperty(PropertyId::BackgroundColor, "background-color", "transparent", false)
		.AddParser("color");
	RegisterProperty(PropertyId::BackgroundImage, "background-image", "none", false)
		.AddParser("keyword", "none")
		.AddParser("string");
	RegisterProperty(PropertyId::BackgroundOrigin, "background-origin", "padding-box", false)
		.AddParser("keyword", "padding-box, border-box, content-box");
	RegisterProperty(PropertyId::BackgroundSize, "background-size", "auto", false)
		.AddParser("keyword", "auto, cover, contain");
	RegisterProperty(PropertyId::BackgroundSizeX, "background-size-x", "0px", false)
		.AddParser("length_percent");
	RegisterProperty(PropertyId::BackgroundSizeY, "background-size-y", "0px", false)
		.AddParser("length_percent");
	RegisterShorthand(ShorthandId::BackgroundSize, "background-size", "background-size-x, background-size-y", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::BackgroundPositionX, "background-position-x", "0%", false)
		.AddParser("keyword", "left, center, right")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::BackgroundPositionY, "background-position-y", "0%", false)
		.AddParser("keyword", "top, center, bottom")
		.AddParser("length_percent");
	RegisterShorthand(ShorthandId::BackgroundPosition, "background-position", "background-position-x, background-position-y", ShorthandType::FallThrough);
	
	RegisterProperty(PropertyId::BackgroundRepeat, "background-repeat", "repeat", false)
		.AddParser("keyword", "repeat, repeat-x, repeat-y, no-repeat");
	RegisterShorthand(ShorthandId::Background, "background", "background-image, background-position-x, background-position-y, background-size-x, background-size-y", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::TextShadowH, "text-shadow-h", "0px", true)
		.AddParser("length");
	RegisterProperty(PropertyId::TextShadowV, "text-shadow-v", "0px", true)
		.AddParser("length");
	RegisterProperty(PropertyId::TextShadowColor, "text-shadow-color", "white", true)
		.AddParser("color");
	RegisterShorthand(ShorthandId::TextShadow, "text-shadow", "text-shadow-h, text-shadow-v, text-shadow-color", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::TextStrokeWidth, "-webkit-text-stroke-width", "0px", false)
		.AddParser("length");
	RegisterProperty(PropertyId::TextStrokeColor, "-webkit-text-stroke-color", "white", false)
		.AddParser("color");
	RegisterShorthand(ShorthandId::TextStroke, "-webkit-text-stroke", "-webkit-text-stroke-width, -webkit-text-stroke-color", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::OutlineWidth, "outline-width", "0px", false)
		.AddParser("length");
	RegisterProperty(PropertyId::OutlineColor, "outline-color", "white", false)
		.AddParser("color");
	RegisterShorthand(ShorthandId::Outline, "outline", "outline-width, outline-color", ShorthandType::FallThrough);

	// flex layout
	RegisterProperty(PropertyId::Display, "display", false)
		.AddParser("keyword", "flex, none");
	RegisterProperty(PropertyId::Overflow, "overflow", false)
		.AddParser("keyword", "visible, hidden, scroll");
	RegisterProperty(PropertyId::Position, "position", false)
		.AddParser("keyword", "static, relative, absolute");

	RegisterProperty(PropertyId::MarginTop, "margin-top", false)
		.AddParser("keyword", "auto")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::MarginRight, "margin-right", false)
		.AddParser("keyword", "auto")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::MarginBottom, "margin-bottom", false)
		.AddParser("keyword", "auto")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::MarginLeft, "margin-left", false)
		.AddParser("keyword", "auto")
		.AddParser("length_percent");
	RegisterShorthand(ShorthandId::Margin, "margin", "margin-top, margin-right, margin-bottom, margin-left", ShorthandType::Box);

	RegisterProperty(PropertyId::PaddingTop, "padding-top", false)
		.AddParser("length_percent");
	RegisterProperty(PropertyId::PaddingRight, "padding-right", false)
		.AddParser("length_percent");
	RegisterProperty(PropertyId::PaddingBottom, "padding-bottom", false)
		.AddParser("length_percent");
	RegisterProperty(PropertyId::PaddingLeft, "padding-left", false)
		.AddParser("length_percent");
	RegisterShorthand(ShorthandId::Padding, "padding", "padding-top, padding-right, padding-bottom, padding-left", ShorthandType::Box);

	RegisterProperty(PropertyId::Top, "top", false)
		.AddParser("length_percent");
	RegisterProperty(PropertyId::Right, "right", false)
		.AddParser("length_percent");
	RegisterProperty(PropertyId::Bottom, "bottom", false)
		.AddParser("length_percent");
	RegisterProperty(PropertyId::Left, "left", false)
		.AddParser("length_percent");

	RegisterProperty(PropertyId::Width, "width", false)
		.AddParser("keyword", "auto")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::MinWidth, "min-width", false)
		.AddParser("length_percent");
	RegisterProperty(PropertyId::MaxWidth, "max-width", false)
		.AddParser("length_percent");

	RegisterProperty(PropertyId::Height, "height", false)
		.AddParser("keyword", "auto")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::MinHeight, "min-height", false)
		.AddParser("length_percent");
	RegisterProperty(PropertyId::MaxHeight, "max-height", false)
		.AddParser("length_percent");
	
	RegisterProperty(PropertyId::AlignContent, "align-content", false)
		.AddParser("keyword", "auto, flex-start, center, flex-end, stretch, baseline, space-between, space-around");
	RegisterProperty(PropertyId::AlignItems, "align-items", false)
		.AddParser("keyword", "auto, flex-start, center, flex-end, stretch, baseline, space-between, space-around");
	RegisterProperty(PropertyId::AlignSelf, "align-self", false)
		.AddParser("keyword", "auto, flex-start, center, flex-end, stretch, baseline, space-between, space-around");
	RegisterProperty(PropertyId::Direction, "direction", false)
		.AddParser("keyword", "inherit, ltr, rtl");
	RegisterProperty(PropertyId::FlexDirection, "flex-direction", false)
		.AddParser("keyword", "column, column-reverse, row, row-reverse");
	RegisterProperty(PropertyId::FlexWrap, "flex-wrap", false)
		.AddParser("keyword", "nowrap, wrap, wrap-reverse");
	RegisterProperty(PropertyId::JustifyContent, "justify-content", false)
		.AddParser("keyword", "flex-start, center, flex-end, space-between, space-around, space-evenly");

	RegisterProperty(PropertyId::AspectRatio, "aspect-ratio", false)
		.AddParser("number");
	RegisterProperty(PropertyId::Flex, "flex", false)
		.AddParser("number");
	RegisterProperty(PropertyId::FlexBasis, "flex-basis", false)
		.AddParser("keyword", "auto")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::FlexGrow, "flex-grow", false)
		.AddParser("number");
	RegisterProperty(PropertyId::FlexShrink, "flex-shrink", false)
		.AddParser("number");

	RegisterProperty(PropertyId::PointerEvents, "pointer-events", "auto", false)
		.AddParser("keyword", "none, auto");
	RegisterProperty(PropertyId::ScrollLeft, "scroll-left", "0px", false)
		.AddParser("length");
	RegisterProperty(PropertyId::ScrollTop, "scroll-top", "0px", false)
		.AddParser("length");
}

static StyleSheetSpecificationInstance* instance = nullptr;

bool StyleSheetSpecification::Initialise() {
	if (instance == nullptr) {
		instance = new StyleSheetSpecificationInstance();
		instance->RegisterProperties();
	}
	return true;
}

void StyleSheetSpecification::Shutdown() {
	if (instance != nullptr) {
		delete instance;
	}
}

PropertyParser* StyleSheetSpecification::GetParser(const std::string& parser_name) {
	auto iterator = instance->parsers.find(parser_name);
	if (iterator == instance->parsers.end())
		return nullptr;
	return (*iterator).second;
}

const PropertyDefinition* StyleSheetSpecification::GetPropertyDefinition(PropertyId id) {
	return instance->GetPropertyDefinition(id);
}

const PropertyIdSet & StyleSheetSpecification::GetRegisteredInheritedProperties() {
	return instance->GetRegisteredInheritedProperties();
}

bool StyleSheetSpecification::ParsePropertyDeclaration(PropertyIdSet& set, const std::string& property_name) {
	return instance->ParsePropertyDeclaration(set, property_name);
}

bool StyleSheetSpecification::ParsePropertyDeclaration(PropertyDictionary& dictionary, const std::string& property_name, const std::string& property_value) {
	return instance->ParsePropertyDeclaration(dictionary, property_name, property_value);
}

}
