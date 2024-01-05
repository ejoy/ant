#include <css/StyleSheetSpecification.h>
#include <css/StyleCache.h>
#include <css/PropertyIdSet.h>
#include <util/Log.h>
#include <util/StringUtilities.h>
#include <css/PropertyParserNumber.h>
#include <css/PropertyParserAnimation.h>
#include <css/PropertyParserColour.h>
#include <css/PropertyParserKeyword.h>
#include <css/PropertyParserString.h>
#include <css/PropertyParserTransform.h>
#include <core/Layout.h>
#include <array>
#include <memory>

namespace Rml {

class StyleSheetSpecification;
struct StyleSheetSpecificationInstance;

template<class> inline constexpr bool always_false_v = false;

enum class ShorthandType : uint8_t {
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

struct PropertyDefinition {
	std::vector<PropertyParser*> parsers;
};

struct ShorthandItem {
	std::variant<PropertyId, ShorthandId> definition;
	bool optional;
};

struct ShorthandDefinition {
	ShorthandType type;
	std::vector<ShorthandItem> items;
};

struct PropertyRegister {
	StyleSheetSpecificationInstance& instance;
	PropertyDefinition& definition;
	PropertyParser*   GetParser(const std::string& parser_name);
	PropertyParser*   GetKeywordParser(const std::string& parser_parameters);
	PropertyRegister& AddParser(const std::string& parser_name);
	PropertyRegister& AddParser(const std::string& parser_name, const std::string& parser_parameters);
};

static constexpr inline PropertyIdSet GetInheritableProperties() {
	PropertyIdSet set;
	set.insert(PropertyId::LineHeight);
	set.insert(PropertyId::Color);
	set.insert(PropertyId::Opacity);
	set.insert(PropertyId::FontFamily);
	set.insert(PropertyId::FontSize);
	set.insert(PropertyId::FontStyle);
	set.insert(PropertyId::FontWeight);
	set.insert(PropertyId::TextAlign);
	set.insert(PropertyId::WordBreak);
	set.insert(PropertyId::TextDecorationLine);
	set.insert(PropertyId::TextDecorationColor);
	set.insert(PropertyId::TextShadowH);
	set.insert(PropertyId::TextShadowV);
	set.insert(PropertyId::TextShadowColor);
	return set;
}
static constexpr PropertyIdSet InheritableProperties = GetInheritableProperties();
static_assert((InheritableProperties & LayoutProperties).empty());

struct StyleSheetSpecificationInstance {
	~StyleSheetSpecificationInstance();
	PropertyRegister RegisterProperty(PropertyId id, const std::string& property_name);
	PropertyRegister RegisterProperty(PropertyId id, const std::string& property_name, const std::string& default_value);
	bool RegisterShorthand(ShorthandId id, const std::string& shorthand_name, const std::string& property_names, ShorthandType type);
	void RegisterProperties();

	std::optional<Property> ParseProperty(PropertyId id, const std::string& value) const;

	Style::TableValue GetDefaultProperties() const;
	const PropertyIdSet& GetInheritableProperties() const;
	const ShorthandDefinition& GetShorthandDefinition(ShorthandId id) const;
	bool ParsePropertyDeclaration(PropertyIdSet& set, const std::string& property_name) const;
	bool ParsePropertyDeclaration(PropertyVector& vec, const std::string& property_name, const std::string& property_value) const;
	bool ParsePropertyDeclaration(PropertyVector& vec, PropertyId property_id, const std::string& property_value) const;
	void ParseShorthandDeclaration(PropertyIdSet& set, ShorthandId shorthand_id) const;
	bool ParseShorthandDeclaration(PropertyVector& vec, ShorthandId shorthand_id, const std::string& property_value) const;
	bool ParsePropertyValues(std::vector<std::string>& values_list, const std::string& values, bool split_values) const;

	std::unordered_map<std::string, PropertyParser*> parsers = {
		{"number", new PropertyParserNumber(PropertyParserNumber::UnitMark::Number)},
		{"length", new PropertyParserNumber(PropertyParserNumber::UnitMark::Length)},
		{"length_percent", new PropertyParserNumber(PropertyParserNumber::UnitMark::LengthPercent)},
		{"angle", new PropertyParserNumber(PropertyParserNumber::UnitMark::Angle)},
		{"string", new PropertyParserString()},
		{"animation", new PropertyParserAnimation()},
		{"transition", new PropertyParserTransition()},
		{"color", new PropertyParserColour()},
		{"transform", new PropertyParserTransform()},
	};
	std::unordered_map<std::string, PropertyParser*> keyword_parsers;
	std::array<PropertyDefinition,  EnumCountV<PropertyId>>  properties;
	std::array<ShorthandDefinition, EnumCountV<ShorthandId>> shorthands;
	std::unordered_map<std::string, PropertyId> property_map;
	std::unordered_map<std::string, ShorthandId> shorthand_map;
	std::unordered_map<PropertyId, std::string> unparsed_default;
	Style::TableValue default_value;
};

PropertyParser* PropertyRegister::GetParser(const std::string& parser_name) {
	auto iterator = instance.parsers.find(parser_name);
	if (iterator == instance.parsers.end())
		return nullptr;
	return (*iterator).second;
}

PropertyParser* PropertyRegister::GetKeywordParser(const std::string& parser_parameters) {
	auto it = instance.keyword_parsers.find(parser_parameters);
	if (it != instance.keyword_parsers.end()) {
		return it->second;
	}
	PropertyParserKeyword* new_parser = new PropertyParserKeyword();
	std::vector<std::string> parameter_list;
	StringUtilities::ExpandString(parameter_list, parser_parameters, ',');
	for (size_t i = 0; i < parameter_list.size(); i++) {
		new_parser->parameters[parameter_list[i]] = (int) i;
	}
	instance.keyword_parsers.emplace(parser_parameters, new_parser);
	return new_parser;
}

PropertyRegister& PropertyRegister::AddParser(const std::string& parser_name) {
	PropertyParser* new_parser = GetParser(parser_name);
	if (new_parser == nullptr) {
		Log::Message(Log::Level::Error, "Property was registered with invalid parser '%s'.", parser_name.c_str());
		return *this;
	}
	definition.parsers.push_back(new_parser);
	return *this;
}

PropertyRegister& PropertyRegister::AddParser(const std::string& parser_name, const std::string& parser_parameters) {
	assert(parser_name == "keyword");
	PropertyParser* new_parser = GetKeywordParser(parser_parameters);
	if (new_parser == nullptr) {
		Log::Message(Log::Level::Error, "Property was registered with invalid parser '%s'.", parser_name.c_str());
		return *this;
	}
	definition.parsers.push_back(new_parser);
	return *this;
}

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
std::optional<T> MapGet(std::unordered_map<std::string, T> const& map, const std::string& name)  {
	auto it = map.find(name);
	if (it != map.end())
		return it->second;
	return std::nullopt;
}

template <typename T>
std::optional<std::string> MapGetName(std::unordered_map<std::string, T> const& map, T const& v)  {
	for (auto& [name, value]: map) {
		if (value == v) {
			return name;
		}
	}
	return std::nullopt;
}

StyleSheetSpecificationInstance::~StyleSheetSpecificationInstance() {
	for (auto [_, parser] : parsers) {
		delete parser;
	}
	for (auto [_, parser] : keyword_parsers) {
		delete parser;
	}
	Style::Shutdown();
}

PropertyRegister StyleSheetSpecificationInstance::RegisterProperty(PropertyId id, const std::string& property_name, const std::string& default_value) {
	MapAdd(property_map, property_name, id);
	size_t index = (size_t)id;
	unparsed_default[id] = default_value;
	return { *this, properties[index] };
}

PropertyRegister StyleSheetSpecificationInstance::RegisterProperty(PropertyId id, const std::string& property_name) {
	MapAdd(property_map, property_name, id);
	size_t index = (size_t)id;
	return { *this, properties[index] };
}

std::optional<Property> StyleSheetSpecificationInstance::ParseProperty(PropertyId id, const std::string& value) const {
	auto& definition = properties[(size_t)id];
	for (auto parser : definition.parsers) {
		auto property = parser->ParseValue(value);
		if (property) {
			return property;
		}
	}
	return std::nullopt;
}

Style::TableValue StyleSheetSpecificationInstance::GetDefaultProperties() const {
	return default_value;
}

const PropertyIdSet& StyleSheetSpecificationInstance::GetInheritableProperties() const {
	return InheritableProperties;
}

bool StyleSheetSpecificationInstance::RegisterShorthand(ShorthandId id, const std::string& shorthand_name, const std::string& property_names, ShorthandType type) {
	MapAdd(shorthand_map, shorthand_name, id);

	std::vector<std::string> property_list;
	StringUtilities::ExpandString(property_list, property_names, ',');

	auto& property_shorthand = shorthands[(size_t)id];

	for (const std::string& raw_name : property_list) {
		bool optional = false;
		std::optional<ShorthandItem> item;
		std::string name = raw_name;

		if (!raw_name.empty() && raw_name.back() == '?') {
			optional = true;
			name.pop_back();
		}

		auto property_id = MapGet(property_map, name);
		if (property_id) {
			// We have a valid property
			item = { *property_id, optional };
		}
		else {
			// Otherwise, we must be a shorthand
			auto shorthand_id = MapGet(shorthand_map, name);

			// Test for valid shorthand id. The recursive types (and only those) can hold other shorthands.
			if (shorthand_id && (type == ShorthandType::RecursiveRepeat || type == ShorthandType::RecursiveCommaSeparated)) {
				item = { *shorthand_id, optional };
			}
		}

		if (!item) {
			Log::Message(Log::Level::Error, "Shorthand property '%s' was registered with invalid property '%s'.", shorthand_name.c_str(), name.c_str());
			return false;
		}
		property_shorthand.items.emplace_back(std::move(*item));
	}

	property_shorthand.type = type;
	return true;
}

const ShorthandDefinition& StyleSheetSpecificationInstance::GetShorthandDefinition(ShorthandId id) const {
	return shorthands[(size_t)id];
}

void StyleSheetSpecificationInstance::ParseShorthandDeclaration(PropertyIdSet& set, ShorthandId shorthand_id) const {
	const ShorthandDefinition& shorthand_definition = GetShorthandDefinition(shorthand_id);
	for (auto& item : shorthand_definition.items) {
		std::visit([&](auto&& arg) {
			using T = std::decay_t<decltype(arg)>;
			if constexpr (std::is_same_v<T, PropertyId>) {
				set.insert(arg);
			}
			else if constexpr (std::is_same_v<T, ShorthandId>) {
				ParseShorthandDeclaration(set, arg);
			}
			else {
				static_assert(always_false_v<T>, "non-exhaustive visitor!");
			}
		}, item.definition);
	}
}

bool StyleSheetSpecificationInstance::ParsePropertyDeclaration(PropertyIdSet& set, const std::string& property_name) const {
	auto property_id = MapGet(property_map, property_name);
	if (property_id) {
		set.insert(*property_id);
		return true;
	}
	auto shorthand_id = MapGet(shorthand_map, property_name);
	if (shorthand_id) {
		ParseShorthandDeclaration(set, *shorthand_id);
		return true;
	}
	return false;
}

bool StyleSheetSpecificationInstance::ParsePropertyDeclaration(PropertyVector& vec, const std::string& property_name, const std::string& property_value) const {
	auto property_id = MapGet(property_map, property_name);
	if (property_id) {
		if (ParsePropertyDeclaration(vec, *property_id, property_value)) {
			return true;
		}
	}
	auto shorthand_id = MapGet(shorthand_map, property_name);
	if (shorthand_id) {
		if (ParseShorthandDeclaration(vec, *shorthand_id, property_value)){
			return true;
		}
	}
	return false;
}

bool StyleSheetSpecificationInstance::ParsePropertyDeclaration(PropertyVector& vec, PropertyId property_id, const std::string& property_value) const {
	// Parse as a single property.
	std::vector<std::string> property_values;
	if (!ParsePropertyValues(property_values, property_value, false) || property_values.size() == 0)
		return false;
	auto new_property = ParseProperty(property_id, property_values[0]);
	if (!new_property)
		return false;
	vec.emplace_back(property_id, std::move(*new_property));
	return true;
}

// Parses a property declaration, setting any parsed and validated properties on the given dictionary.
bool StyleSheetSpecificationInstance::ParseShorthandDeclaration(PropertyVector& vec, ShorthandId shorthand_id, const std::string& property_value) const {
	std::vector<std::string> property_values;
	if (!ParsePropertyValues(property_values, property_value, true) || property_values.size() == 0)
		return false;

	// Parse as a shorthand.
	const ShorthandDefinition& shorthand_definition = GetShorthandDefinition(shorthand_id);

	// If this definition is a 'box'-style shorthand (x-top, x-right, x-bottom, x-left, etc) and there are fewer
	// than four values
	if (shorthand_definition.type == ShorthandType::Box && property_values.size() < 4) {
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
			const ShorthandItem& item = shorthand_definition.items[i];
			auto id = std::get_if<PropertyId>(&item.definition);
			if (!id) {
				return false;
			}
			int value_index = box_side_to_value_index[i];
			auto new_property = ParseProperty(*id, property_values[value_index]);
			if (!new_property) {
				return false;
			}
			vec.emplace_back(*id, std::move(*new_property));
		}
	}
	else if (shorthand_definition.type == ShorthandType::RecursiveRepeat) {
		bool result = true;

		for (auto& item : shorthand_definition.items) {
			std::visit([&](auto&& arg) {
				using T = std::decay_t<decltype(arg)>;
				if constexpr (std::is_same_v<T, PropertyId>) {
					result &= ParsePropertyDeclaration(vec, arg, property_value);
				}
				else if constexpr (std::is_same_v<T, ShorthandId>) {
					result &= ParseShorthandDeclaration(vec, arg, property_value);
				}
				else {
					static_assert(always_false_v<T>, "non-exhaustive visitor!");
				}
			}, item.definition);
		}

		if (!result)
			return false;
	}
	else if (shorthand_definition.type == ShorthandType::RecursiveCommaSeparated) {
		std::vector<std::string> subvalues;
		StringUtilities::ExpandString(subvalues, property_value, ',');

		size_t num_optional = 0;
		for (auto& item : shorthand_definition.items)
			if (item.optional)
				num_optional += 1;

		if (subvalues.size() + num_optional < shorthand_definition.items.size()) {
			// Not enough subvalues declared.
			return false;
		}

		size_t subvalue_i = 0;
		for (size_t i = 0; i < shorthand_definition.items.size() && subvalue_i < subvalues.size(); i++) {
			bool result = false;
			const ShorthandItem& item = shorthand_definition.items[i];

			std::visit([&](auto&& arg) {
				using T = std::decay_t<decltype(arg)>;
				if constexpr (std::is_same_v<T, PropertyId>) {
					result = ParsePropertyDeclaration(vec, arg, subvalues[subvalue_i]);
				}
				else if constexpr (std::is_same_v<T, ShorthandId>) {
					result = ParseShorthandDeclaration(vec, arg, subvalues[subvalue_i]);
				}
				else {
					static_assert(always_false_v<T>, "non-exhaustive visitor!");
				}
			}, item.definition);

			if (result)
				subvalue_i += 1;
			else if (!item.optional)
				return false;
		}
	}
	else {
		size_t value_index = 0;
		size_t property_index = 0;

		for (; value_index < property_values.size() && property_index < shorthand_definition.items.size(); property_index++) {
			const ShorthandItem& item = shorthand_definition.items[property_index];
			auto id = std::get_if<PropertyId>(&item.definition);
			if (!id) {
				return false;
			}
			auto new_property = ParseProperty(*id, property_values[value_index]);
			if (!new_property) {
				// This definition failed to parse; if we're falling through, try the next property. If there is no
				// next property, then abort!
				if (shorthand_definition.type == ShorthandType::FallThrough) {
					if (property_index + 1 < shorthand_definition.items.size())
						continue;
				}
				return false;
			}

			vec.emplace_back(*id, std::move(*new_property));

			// Increment the value index, unless we're replicating the last value and we're up to the last value.
			if (shorthand_definition.type != ShorthandType::Replicate ||
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
		if (value.size() > 0 || values_list.size() == 0) {
			values_list.push_back(value);
		}
	}

	return true;
}

void StyleSheetSpecificationInstance::RegisterProperties() {
	RegisterProperty(PropertyId::BorderTopWidth, "border-top-width", "0px")
		.AddParser("length");
	RegisterProperty(PropertyId::BorderRightWidth, "border-right-width", "0px")
		.AddParser("length");
	RegisterProperty(PropertyId::BorderBottomWidth, "border-bottom-width", "0px")
		.AddParser("length");
	RegisterProperty(PropertyId::BorderLeftWidth, "border-left-width", "0px")
		.AddParser("length");
	RegisterShorthand(ShorthandId::BorderWidth, "border-width", "border-top-width, border-right-width, border-bottom-width, border-left-width", ShorthandType::Box);

	RegisterProperty(PropertyId::BorderTopColor, "border-top-color", "transparent")
		.AddParser("color");
	RegisterProperty(PropertyId::BorderRightColor, "border-right-color", "transparent")
		.AddParser("color");
	RegisterProperty(PropertyId::BorderBottomColor, "border-bottom-color", "transparent")
		.AddParser("color");
	RegisterProperty(PropertyId::BorderLeftColor, "border-left-color", "transparent")
		.AddParser("color");
	RegisterShorthand(ShorthandId::BorderColor, "border-color", "border-top-color, border-right-color, border-bottom-color, border-left-color", ShorthandType::Box);

	RegisterShorthand(ShorthandId::BorderTop, "border-top", "border-top-width, border-top-color", ShorthandType::FallThrough);
	RegisterShorthand(ShorthandId::BorderRight, "border-right", "border-right-width, border-right-color", ShorthandType::FallThrough);
	RegisterShorthand(ShorthandId::BorderBottom, "border-bottom", "border-bottom-width, border-bottom-color", ShorthandType::FallThrough);
	RegisterShorthand(ShorthandId::BorderLeft, "border-left", "border-left-width, border-left-color", ShorthandType::FallThrough);
	RegisterShorthand(ShorthandId::Border, "border", "border-top, border-right, border-bottom, border-left", ShorthandType::RecursiveRepeat);

	RegisterProperty(PropertyId::BorderTopLeftRadius, "border-top-left-radius", "0px")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::BorderTopRightRadius, "border-top-right-radius", "0px")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::BorderBottomRightRadius, "border-bottom-right-radius", "0px")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::BorderBottomLeftRadius, "border-bottom-left-radius", "0px")
		.AddParser("length_percent");
	RegisterShorthand(ShorthandId::BorderRadius, "border-radius", "border-top-left-radius, border-top-right-radius, border-bottom-right-radius, border-bottom-left-radius", ShorthandType::Box);

	RegisterProperty(PropertyId::ZIndex, "z-index", "0")
		.AddParser("number");

	RegisterProperty(PropertyId::LineHeight, "line-height", "normal")
		.AddParser("keyword", "normal")
		.AddParser("number");

	RegisterProperty(PropertyId::Color, "color", "white")
		.AddParser("color");

	RegisterProperty(PropertyId::Opacity, "opacity", "1")
		.AddParser("number");

	RegisterProperty(PropertyId::FontFamily, "font-family", "")
		.AddParser("string");
	RegisterProperty(PropertyId::FontStyle, "font-style", "normal")
		.AddParser("keyword", "normal, italic");
	RegisterProperty(PropertyId::FontWeight, "font-weight", "normal")
		.AddParser("keyword", "normal, bold");
	RegisterProperty(PropertyId::FontSize, "font-size", "12px")
		.AddParser("length")
		.AddParser("length_percent");
	RegisterShorthand(ShorthandId::Font, "font", "font-style, font-weight, font-size, font-family", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::TextAlign, "text-align", "left")
		.AddParser("keyword", "left, right, center, justify");
	RegisterProperty(PropertyId::WordBreak, "word-break", "normal")
		.AddParser("keyword", "normal, break-all, break-word");

	RegisterProperty(PropertyId::TextDecorationLine, "text-decoration-line", "none")
		.AddParser("keyword", "none, underline, overline, line-through");
	RegisterProperty(PropertyId::TextDecorationColor, "text-decoration-color", "currentColor")
		.AddParser("keyword", "currentColor")
		.AddParser("color");
	RegisterShorthand(ShorthandId::TextDecoration, "text-decoration", "text-decoration-line, text-decoration-color", ShorthandType::FallThrough);
	
	// Perspective and Transform specifications
	RegisterProperty(PropertyId::Perspective, "perspective", "none")
		.AddParser("keyword", "none")
		.AddParser("length");
	RegisterProperty(PropertyId::PerspectiveOriginX, "perspective-origin-x", "50%")
		.AddParser("keyword", "left, center, right")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::PerspectiveOriginY, "perspective-origin-y", "50%")
		.AddParser("keyword", "top, center, bottom")
		.AddParser("length_percent");
	RegisterShorthand(ShorthandId::PerspectiveOrigin, "perspective-origin", "perspective-origin-x, perspective-origin-y", ShorthandType::FallThrough);
	RegisterProperty(PropertyId::Transform, "transform", "none")
		.AddParser("transform");
	RegisterProperty(PropertyId::TransformOriginX, "transform-origin-x", "50%")
		.AddParser("keyword", "left, center, right")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::TransformOriginY, "transform-origin-y", "50%")
		.AddParser("keyword", "top, center, bottom")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::TransformOriginZ, "transform-origin-z", "0px")
		.AddParser("length");
	RegisterShorthand(ShorthandId::TransformOrigin, "transform-origin", "transform-origin-x, transform-origin-y, transform-origin-z", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::Transition, "transition", "none")
		.AddParser("transition");
	RegisterProperty(PropertyId::Animation, "animation", "none")
		.AddParser("animation");

	RegisterProperty(PropertyId::BackgroundColor, "background-color", "transparent")
		.AddParser("color");
	RegisterProperty(PropertyId::BackgroundImage, "background-image", "none")
		.AddParser("keyword", "none")
		.AddParser("string");
	RegisterProperty(PropertyId::BackgroundOrigin, "background-origin", "padding-box")
		.AddParser("keyword", "padding-box, border-box, content-box");
	RegisterProperty(PropertyId::BackgroundSize, "background-size", "unset")
		.AddParser("keyword", "unset, auto, cover, contain");
	RegisterProperty(PropertyId::BackgroundSizeX, "background-size-x", "0px")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::BackgroundSizeY, "background-size-y", "0px")
		.AddParser("length_percent");
	RegisterShorthand(ShorthandId::BackgroundSize, "background-size", "background-size-x, background-size-y", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::BackgroundPositionX, "background-position-x", "0%")
		.AddParser("keyword", "left, center, right")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::BackgroundPositionY, "background-position-y", "0%")
		.AddParser("keyword", "top, center, bottom")
		.AddParser("length_percent");
	RegisterShorthand(ShorthandId::BackgroundPosition, "background-position", "background-position-x, background-position-y", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::BackgroundLattice, "background-lattice", "auto")
		.AddParser("keyword", "auto, cover, contain");	
	RegisterProperty(PropertyId::BackgroundLatticeX1, "background-lattice-x1", "0%")
		.AddParser("keyword", "left, center, right")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::BackgroundLatticeY1, "background-lattice-y1", "0%")
		.AddParser("keyword", "top, center, bottom")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::BackgroundLatticeX2, "background-lattice-x2", "0%")
		.AddParser("keyword", "left, center, right")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::BackgroundLatticeY2, "background-lattice-y2", "0%")
		.AddParser("keyword", "top, center, bottom")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::BackgroundLatticeU, "background-lattice-u", "0%")
		.AddParser("keyword", "top, center, bottom")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::BackgroundLatticeV, "background-lattice-v", "0%")
		.AddParser("keyword", "top, center, bottom")
		.AddParser("length_percent");
	RegisterShorthand(ShorthandId::BackgroundLattice, "background-lattice", "background-lattice-x1, background-lattice-y1, background-lattice-x2, background-lattice-y2, background-lattice-u, background-lattice-v", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::BackgroundRepeat, "background-repeat", "repeat")
		.AddParser("keyword", "repeat, repeat-x, repeat-y, no-repeat");
	RegisterProperty(PropertyId::BackgroundFilter, "background-filter", "none")
		.AddParser("keyword", "none")
		.AddParser("color");
	RegisterShorthand(ShorthandId::Background, "background", "background-image, background-position-x, background-position-y, background-size-x, background-size-y", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::TextShadowH, "text-shadow-h", "0px")
		.AddParser("length");
	RegisterProperty(PropertyId::TextShadowV, "text-shadow-v", "0px")
		.AddParser("length");
	RegisterProperty(PropertyId::TextShadowColor, "text-shadow-color", "white")
		.AddParser("color");
	RegisterShorthand(ShorthandId::TextShadow, "text-shadow", "text-shadow-h, text-shadow-v, text-shadow-color", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::TextStrokeWidth, "-webkit-text-stroke-width", "0px")
		.AddParser("length");
	RegisterProperty(PropertyId::TextStrokeColor, "-webkit-text-stroke-color", "white")
		.AddParser("color");
	RegisterShorthand(ShorthandId::TextStroke, "-webkit-text-stroke", "-webkit-text-stroke-width, -webkit-text-stroke-color", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::OutlineWidth, "outline-width", "0px")
		.AddParser("length");
	RegisterProperty(PropertyId::OutlineColor, "outline-color", "white")
		.AddParser("color");
	RegisterShorthand(ShorthandId::Outline, "outline", "outline-width, outline-color", ShorthandType::FallThrough);

	// flex layout
	RegisterProperty(PropertyId::Display, "display")
		.AddParser("keyword", "flex, none");
	RegisterProperty(PropertyId::Overflow, "overflow")
		.AddParser("keyword", "visible, hidden, scroll");
	RegisterProperty(PropertyId::Position, "position")
		.AddParser("keyword", "static, relative, absolute");

	RegisterProperty(PropertyId::MarginTop, "margin-top")
		.AddParser("keyword", "auto")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::MarginRight, "margin-right")
		.AddParser("keyword", "auto")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::MarginBottom, "margin-bottom")
		.AddParser("keyword", "auto")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::MarginLeft, "margin-left")
		.AddParser("keyword", "auto")
		.AddParser("length_percent");
	RegisterShorthand(ShorthandId::Margin, "margin", "margin-top, margin-right, margin-bottom, margin-left", ShorthandType::Box);

	RegisterProperty(PropertyId::PaddingTop, "padding-top")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::PaddingRight, "padding-right")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::PaddingBottom, "padding-bottom")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::PaddingLeft, "padding-left")
		.AddParser("length_percent");
	RegisterShorthand(ShorthandId::Padding, "padding", "padding-top, padding-right, padding-bottom, padding-left", ShorthandType::Box);

	RegisterProperty(PropertyId::Top, "top")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::Right, "right")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::Bottom, "bottom")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::Left, "left")
		.AddParser("length_percent");

	RegisterProperty(PropertyId::Width, "width")
		.AddParser("keyword", "auto")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::MinWidth, "min-width")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::MaxWidth, "max-width")
		.AddParser("length_percent");

	RegisterProperty(PropertyId::Height, "height")
		.AddParser("keyword", "auto")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::MinHeight, "min-height")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::MaxHeight, "max-height")
		.AddParser("length_percent");

	RegisterProperty(PropertyId::ColumnGap, "column-gap")
		.AddParser("length");
	RegisterProperty(PropertyId::RowGap, "row-gap")
		.AddParser("length");
	RegisterProperty(PropertyId::Gap, "gap")
		.AddParser("length");
	
	RegisterProperty(PropertyId::AlignContent, "align-content")
		.AddParser("keyword", "auto, flex-start, center, flex-end, stretch, baseline, space-between, space-around, space-evenly");
	RegisterProperty(PropertyId::AlignItems, "align-items")
		.AddParser("keyword", "auto, flex-start, center, flex-end, stretch, baseline, space-between, space-around");
	RegisterProperty(PropertyId::AlignSelf, "align-self")
		.AddParser("keyword", "auto, flex-start, center, flex-end, stretch, baseline, space-between, space-around");
	RegisterProperty(PropertyId::Direction, "direction")
		.AddParser("keyword", "inherit, ltr, rtl");
	RegisterProperty(PropertyId::FlexDirection, "flex-direction")
		.AddParser("keyword", "column, column-reverse, row, row-reverse");
	RegisterProperty(PropertyId::FlexWrap, "flex-wrap")
		.AddParser("keyword", "nowrap, wrap, wrap-reverse");
	RegisterProperty(PropertyId::JustifyContent, "justify-content")
		.AddParser("keyword", "flex-start, center, flex-end, space-between, space-around, space-evenly");

	RegisterProperty(PropertyId::AspectRatio, "aspect-ratio")
		.AddParser("number");
	RegisterProperty(PropertyId::Flex, "flex")
		.AddParser("number");
	RegisterProperty(PropertyId::FlexBasis, "flex-basis")
		.AddParser("keyword", "auto")
		.AddParser("length_percent");
	RegisterProperty(PropertyId::FlexGrow, "flex-grow")
		.AddParser("number");
	RegisterProperty(PropertyId::FlexShrink, "flex-shrink")
		.AddParser("number");

	RegisterProperty(PropertyId::PointerEvents, "pointer-events", "auto")
		.AddParser("keyword", "none, auto");
	RegisterProperty(PropertyId::ScrollLeft, "scroll-left", "0px")
		.AddParser("length");
	RegisterProperty(PropertyId::ScrollTop, "scroll-top", "0px")
		.AddParser("length");
	RegisterProperty(PropertyId::Filter, "filter", "none")
		.AddParser("keyword", "none,gray");
	PropertyVector properties;
	for (auto const& [id, value] : unparsed_default) {
		if (!ParsePropertyDeclaration(properties, id, value)) {
			auto name = MapGetName(property_map, id);
			Log::Message(Log::Level::Error, "property '%s' default value (%s) parse failed..", name? name->c_str(): "unk", value.c_str());
		}
	}
	unparsed_default.clear();
	Style::Initialise(InheritableProperties);
	default_value = Style::Instance().Create(properties);
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

Style::TableValue StyleSheetSpecification::GetDefaultProperties() {
	return instance->GetDefaultProperties();
}

const PropertyIdSet & StyleSheetSpecification::GetInheritableProperties() {
	return instance->GetInheritableProperties();
}

bool StyleSheetSpecification::ParsePropertyDeclaration(PropertyIdSet& set, const std::string& property_name) {
	return instance->ParsePropertyDeclaration(set, property_name);
}

bool StyleSheetSpecification::ParsePropertyDeclaration(PropertyVector& vec, const std::string& property_name, const std::string& property_value) {
	return instance->ParsePropertyDeclaration(vec, property_name, property_value);
}

}
