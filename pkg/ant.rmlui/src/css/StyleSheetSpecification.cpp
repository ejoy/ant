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
#include <css/PropertyName.h>
#include <util/AlwaysFalse.h>
#include <core/Layout.h>
#include <array>
#include <memory>
#include <optional>

namespace Rml {

class StyleSheetSpecification;
struct StyleSheetSpecificationInstance;

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

using PropertyParser = Property (*)(PropertyId id, const std::string& value);

struct PropertyDefinition {
	std::vector<PropertyParser> parsers;
};

struct ShorthandDefinition {
	ShorthandType type;
	std::vector<std::variant<PropertyId, ShorthandId>> items;
};

struct PropertyRegister {
	PropertyDefinition& definition;
	PropertyRegister& AddParser(PropertyParser new_parser);
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
	void RegisterProperties();

	bool RegisterShorthand(ShorthandId id, const std::string& shorthand_name, const std::string& property_names, ShorthandType type);

	template <typename... Parser>
	PropertyRegister RegisterProperty(PropertyId id, const std::string&, Parser&&... parser) {
		properties[(size_t)id] = { { parser... } };
		return { properties[(size_t)id] };
	}

	template <typename... Parser>
	PropertyRegister RegisterProperty(PropertyId id, const std::string&, const char def[], Parser&&... parser) {
		unparsed_default[id] = def;
		properties[(size_t)id] = { { parser... } };
		return { properties[(size_t)id] };
	}

	Property ParseProperty(PropertyId id, const std::string& value) const;

	const Style::TableRef& GetDefaultProperties() const;
	const PropertyIdSet& GetInheritableProperties() const;
	const ShorthandDefinition& GetShorthandDefinition(ShorthandId id) const;
	bool ParseDeclaration(PropertyIdSet& set, const std::string& property_name) const;
	bool ParseDeclaration(PropertyVector& vec, const std::string& property_name, const std::string& property_value) const;
	bool ParsePropertyDeclaration(PropertyVector& vec, PropertyId property_id, const std::string& property_value) const;
	void ParseShorthandDeclaration(PropertyIdSet& set, ShorthandId shorthand_id) const;
	bool ParseShorthandDeclaration(PropertyVector& vec, ShorthandId shorthand_id, const std::string& property_value) const;
	bool ParsePropertyValues(std::vector<std::string>& values_list, const std::string& values, bool split_values) const;

	std::array<PropertyDefinition,  EnumCountV<PropertyId>>  properties;
	std::array<ShorthandDefinition, EnumCountV<ShorthandId>> shorthands;
	std::unordered_map<std::string_view, PropertyId> property_map;
	std::unordered_map<std::string_view, ShorthandId> shorthand_map;
	std::unordered_map<PropertyId, std::string> unparsed_default;
	Style::TableRef default_value;
};

PropertyRegister& PropertyRegister::AddParser(PropertyParser new_parser) {
	definition.parsers.push_back(new_parser);
	return *this;
}

template <typename T>
std::optional<T> MapGet(std::unordered_map<std::string_view, T> const& map, std::string_view name)  {
	auto it = map.find(name);
	if (it != map.end())
		return it->second;
	return std::nullopt;
}

Property StyleSheetSpecificationInstance::ParseProperty(PropertyId id, const std::string& value) const {
	auto& definition = properties[(size_t)id];
	for (auto parser : definition.parsers) {
		auto prop = parser(id, value);
		if (prop) {
			return prop;
		}
	}
	return {};
}

const Style::TableRef& StyleSheetSpecificationInstance::GetDefaultProperties() const {
	return default_value;
}

const PropertyIdSet& StyleSheetSpecificationInstance::GetInheritableProperties() const {
	return InheritableProperties;
}

bool StyleSheetSpecificationInstance::RegisterShorthand(ShorthandId id, const std::string& shorthand_name, const std::string& property_names, ShorthandType type) {
	std::vector<std::string> property_list;
	StringUtilities::ExpandString(property_list, property_names, ',');

	auto& property_shorthand = shorthands[(size_t)id];

	for (const std::string& name : property_list) {
		auto property_id = MapGet(property_map, name);
		if (property_id) {
			// We have a valid property
			property_shorthand.items.emplace_back(*property_id);
			continue;
		}
		else {
			// Otherwise, we must be a shorthand
			auto shorthand_id = MapGet(shorthand_map, name);
			// Test for valid shorthand id. The recursive types (and only those) can hold other shorthands.
			if (shorthand_id && (type == ShorthandType::RecursiveRepeat || type == ShorthandType::RecursiveCommaSeparated)) {
				property_shorthand.items.emplace_back(*shorthand_id);
				continue;
			}
			else {
				Log::Message(Log::Level::Error, "Shorthand property '%s' was registered with invalid property '%s'.", shorthand_name.c_str(), name.c_str());
				return false;
			}
		}
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
		}, item);
	}
}

bool StyleSheetSpecificationInstance::ParseDeclaration(PropertyIdSet& set, const std::string& property_name) const {
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

bool StyleSheetSpecificationInstance::ParseDeclaration(PropertyVector& vec, const std::string& property_name, const std::string& property_value) const {
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
	vec.emplace_back(new_property);
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
			auto const& item = shorthand_definition.items[i];
			auto id = std::get_if<PropertyId>(&item);
			if (!id) {
				return false;
			}
			int value_index = box_side_to_value_index[i];
			auto new_property = ParseProperty(*id, property_values[value_index]);
			if (!new_property) {
				return false;
			}
			vec.emplace_back(new_property);
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
			}, item);
		}

		if (!result)
			return false;
	}
	else if (shorthand_definition.type == ShorthandType::RecursiveCommaSeparated) {
		std::vector<std::string> subvalues;
		StringUtilities::ExpandString(subvalues, property_value, ',');

		if (subvalues.size() + 0 < shorthand_definition.items.size()) {
			// Not enough subvalues declared.
			return false;
		}

		size_t subvalue_i = 0;
		for (size_t i = 0; i < shorthand_definition.items.size() && subvalue_i < subvalues.size(); i++) {
			bool result = false;
			auto const& item = shorthand_definition.items[i];

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
			}, item);

			if (result)
				subvalue_i += 1;
		}
	}
	else {
		size_t value_index = 0;
		size_t property_index = 0;

		for (; value_index < property_values.size() && property_index < shorthand_definition.items.size(); property_index++) {
			auto const& item = shorthand_definition.items[property_index];
			auto id = std::get_if<PropertyId>(&item);
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

			vec.emplace_back(new_property);

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
				else if (character == '"' || character == '\'') {
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
					if (character == '"' || character == '\'')
						value += character;
					else {
						value += '/';
						value += character;
					}
				}
				else {
					if (character == '"' || character == '\'') {
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

template <typename E, size_t I, size_t N, typename Data>
static constexpr void GetPropertyName(Data&& data) {
	if constexpr (I < N) {
		data[I] = std::make_tuple(
			static_cast<E>(I),
			PropertyNameV<PropertyNameStyle::Camel, static_cast<E>(I)>,
			PropertyNameV<PropertyNameStyle::Kebab, static_cast<E>(I)>
		);
		GetPropertyName<E, I+1, N>(data);
	}
}

template <typename E>
static consteval auto PropertyNames() {
	std::array<std::tuple<E, std::string_view, std::string_view>, EnumCountV<E>> data;
	GetPropertyName<E, 0, EnumCountV<E>>(data);
	return data;
}

void StyleSheetSpecificationInstance::RegisterProperties() {
	constexpr auto propertyNames = PropertyNames<PropertyId>();
	for (auto [id, camel, kebab]: propertyNames) {
		property_map.emplace(camel, id);
		property_map.emplace(kebab, id);
	}
	for (auto [id, camel, kebab]: PropertyNames<ShorthandId>()) {
		shorthand_map.emplace(camel, id);
		shorthand_map.emplace(kebab, id);
	}

	RegisterProperty(PropertyId::BorderTopWidth,
		"0px",
		PropertyParseNumber<PropertyParseNumberUnit::Length>
	);
	
	RegisterProperty(PropertyId::BorderRightWidth, "border-right-width", "0px")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::BorderBottomWidth, "border-bottom-width", "0px")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::BorderLeftWidth, "border-left-width", "0px")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterShorthand(ShorthandId::BorderWidth, "border-width", "border-top-width, border-right-width, border-bottom-width, border-left-width", ShorthandType::Box);

	RegisterProperty(PropertyId::BorderTopColor, "border-top-color", "transparent")
		.AddParser(PropertyParseColour);
	RegisterProperty(PropertyId::BorderRightColor, "border-right-color", "transparent")
		.AddParser(PropertyParseColour);
	RegisterProperty(PropertyId::BorderBottomColor, "border-bottom-color", "transparent")
		.AddParser(PropertyParseColour);
	RegisterProperty(PropertyId::BorderLeftColor, "border-left-color", "transparent")
		.AddParser(PropertyParseColour);
	RegisterShorthand(ShorthandId::BorderColor, "border-color", "border-top-color, border-right-color, border-bottom-color, border-left-color", ShorthandType::Box);

	RegisterShorthand(ShorthandId::BorderTop, "border-top", "border-top-width, border-top-color", ShorthandType::FallThrough);
	RegisterShorthand(ShorthandId::BorderRight, "border-right", "border-right-width, border-right-color", ShorthandType::FallThrough);
	RegisterShorthand(ShorthandId::BorderBottom, "border-bottom", "border-bottom-width, border-bottom-color", ShorthandType::FallThrough);
	RegisterShorthand(ShorthandId::BorderLeft, "border-left", "border-left-width, border-left-color", ShorthandType::FallThrough);
	RegisterShorthand(ShorthandId::Border, "border", "border-top, border-right, border-bottom, border-left", ShorthandType::RecursiveRepeat);

	RegisterProperty(PropertyId::BorderTopLeftRadius, "border-top-left-radius", "0px")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BorderTopRightRadius, "border-top-right-radius", "0px")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BorderBottomRightRadius, "border-bottom-right-radius", "0px")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BorderBottomLeftRadius, "border-bottom-left-radius", "0px")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterShorthand(ShorthandId::BorderRadius, "border-radius", "border-top-left-radius, border-top-right-radius, border-bottom-right-radius, border-bottom-left-radius", ShorthandType::Box);

	RegisterProperty(PropertyId::ZIndex, "z-index", "0")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Number>);

	RegisterProperty(PropertyId::LineHeight, "line-height", "normal")
		.AddParser(PropertyParseKeyword<"normal">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Number>);

	RegisterProperty(PropertyId::Color, "color", "white")
		.AddParser(PropertyParseColour);

	RegisterProperty(PropertyId::Opacity, "opacity", "1")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Number>);

	RegisterProperty(PropertyId::FontFamily, "font-family", "")
		.AddParser(PropertyParseString);
	RegisterProperty(PropertyId::FontStyle, "font-style", "normal")
		.AddParser(PropertyParseKeyword<"normal", "italic">);
	RegisterProperty(PropertyId::FontWeight, "font-weight", "normal")
		.AddParser(PropertyParseKeyword<"normal", "bold">);
	RegisterProperty(PropertyId::FontSize, "font-size", "12px")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterShorthand(ShorthandId::Font, "font", "font-style, font-weight, font-size, font-family", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::TextAlign, "text-align", "left")
		.AddParser(PropertyParseKeyword<"left", "right", "center", "justify">);
	RegisterProperty(PropertyId::WordBreak, "word-break", "normal")
		.AddParser(PropertyParseKeyword<"normal", "break-all", "break-word">);

	RegisterProperty(PropertyId::TextDecorationLine, "text-decoration-line", "none")
		.AddParser(PropertyParseKeyword<"none", "underline", "overline", "line-through">);
	RegisterProperty(PropertyId::TextDecorationColor, "text-decoration-color", "currentColor")
		.AddParser(PropertyParseKeyword<"currentColor">)
		.AddParser(PropertyParseColour);
	RegisterShorthand(ShorthandId::TextDecoration, "text-decoration", "text-decoration-line, text-decoration-color", ShorthandType::FallThrough);
	
	// Perspective and Transform specifications
	RegisterProperty(PropertyId::Perspective, "perspective", "none")
		.AddParser(PropertyParseKeyword<"none">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::PerspectiveOriginX, "perspective-origin-x", "50%")
		.AddParser(PropertyParseKeyword<"left", "center", "right">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::PerspectiveOriginY, "perspective-origin-y", "50%")
		.AddParser(PropertyParseKeyword<"top", "center", "bottom">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterShorthand(ShorthandId::PerspectiveOrigin, "perspective-origin", "perspective-origin-x, perspective-origin-y", ShorthandType::FallThrough);
	RegisterProperty(PropertyId::Transform, "transform", "none")
		.AddParser(PropertyParseTransform);
	RegisterProperty(PropertyId::TransformOriginX, "transform-origin-x", "50%")
		.AddParser(PropertyParseKeyword<"left", "center", "right">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::TransformOriginY, "transform-origin-y", "50%")
		.AddParser(PropertyParseKeyword<"top", "center", "bottom">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::TransformOriginZ, "transform-origin-z", "0px")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterShorthand(ShorthandId::TransformOrigin, "transform-origin", "transform-origin-x, transform-origin-y, transform-origin-z", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::Transition, "transition", "none")
		.AddParser(PropertyParseTransition);
	RegisterProperty(PropertyId::Animation, "animation", "none")
		.AddParser(PropertyParseAnimation);

	RegisterProperty(PropertyId::BackgroundColor, "background-color", "transparent")
		.AddParser(PropertyParseColour);
	RegisterProperty(PropertyId::BackgroundImage, "background-image", "none")
		.AddParser(PropertyParseKeyword<"none">)
		.AddParser(PropertyParseString);
	RegisterProperty(PropertyId::BackgroundOrigin, "background-origin", "padding-box")
		.AddParser(PropertyParseKeyword<"padding-box", "border-box", "content-box">);
	RegisterProperty(PropertyId::BackgroundSize, "background-size", "unset")
		.AddParser(PropertyParseKeyword<"unset", "auto", "cover", "contain">);
	RegisterProperty(PropertyId::BackgroundSizeX, "background-size-x", "0px")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BackgroundSizeY, "background-size-y", "0px")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterShorthand(ShorthandId::BackgroundSize, "background-size", "background-size-x, background-size-y", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::BackgroundPositionX, "background-position-x", "0%")
		.AddParser(PropertyParseKeyword<"left", "center", "right">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BackgroundPositionY, "background-position-y", "0%")
		.AddParser(PropertyParseKeyword<"top", "center", "bottom">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterShorthand(ShorthandId::BackgroundPosition, "background-position", "background-position-x, background-position-y", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::BackgroundLattice, "background-lattice", "auto")
		.AddParser(PropertyParseKeyword<"auto", "cover", "contain">);	
	RegisterProperty(PropertyId::BackgroundLatticeX1, "background-lattice-x1", "0%")
		.AddParser(PropertyParseKeyword<"left", "center", "right">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BackgroundLatticeY1, "background-lattice-y1", "0%")
		.AddParser(PropertyParseKeyword<"top", "center", "bottom">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BackgroundLatticeX2, "background-lattice-x2", "0%")
		.AddParser(PropertyParseKeyword<"left", "center", "right">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BackgroundLatticeY2, "background-lattice-y2", "0%")
		.AddParser(PropertyParseKeyword<"top", "center", "bottom">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BackgroundLatticeU, "background-lattice-u", "0%")
		.AddParser(PropertyParseKeyword<"top", "center", "bottom">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BackgroundLatticeV, "background-lattice-v", "0%")
		.AddParser(PropertyParseKeyword<"top", "center", "bottom">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterShorthand(ShorthandId::BackgroundLattice, "background-lattice", "background-lattice-x1, background-lattice-y1, background-lattice-x2, background-lattice-y2, background-lattice-u, background-lattice-v", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::BackgroundRepeat, "background-repeat", "repeat")
		.AddParser(PropertyParseKeyword<"repeat", "repeat-x", "repeat-y", "no-repeat">);
	RegisterProperty(PropertyId::BackgroundFilter, "background-filter", "none")
		.AddParser(PropertyParseKeyword<"none">)
		.AddParser(PropertyParseColour);
	RegisterShorthand(ShorthandId::Background, "background", "background-image, background-position-x, background-position-y, background-size-x, background-size-y", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::TextShadowH, "text-shadow-h", "0px")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::TextShadowV, "text-shadow-v", "0px")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::TextShadowColor, "text-shadow-color", "white")
		.AddParser(PropertyParseColour);
	RegisterShorthand(ShorthandId::TextShadow, "text-shadow", "text-shadow-h, text-shadow-v, text-shadow-color", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::_WebkitTextStrokeWidth, "-webkit-text-stroke-width", "0px")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::_WebkitTextStrokeColor, "-webkit-text-stroke-color", "white")
		.AddParser(PropertyParseColour);
	RegisterShorthand(ShorthandId::_WebkitTextStroke, "-webkit-text-stroke", "-webkit-text-stroke-width, -webkit-text-stroke-color", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::OutlineWidth, "outline-width", "0px")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::OutlineColor, "outline-color", "white")
		.AddParser(PropertyParseColour);
	RegisterShorthand(ShorthandId::Outline, "outline", "outline-width, outline-color", ShorthandType::FallThrough);

	// flex layout
	RegisterProperty(PropertyId::Display, "display")
		.AddParser(PropertyParseKeyword<"flex", "none">);
	RegisterProperty(PropertyId::Overflow, "overflow")
		.AddParser(PropertyParseKeyword<"visible", "hidden", "scroll">);
	RegisterProperty(PropertyId::Position, "position")
		.AddParser(PropertyParseKeyword<"static", "relative", "absolute">);

	RegisterProperty(PropertyId::MarginTop, "margin-top")
		.AddParser(PropertyParseKeyword<"auto">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::MarginRight, "margin-right")
		.AddParser(PropertyParseKeyword<"auto">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::MarginBottom, "margin-bottom")
		.AddParser(PropertyParseKeyword<"auto">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::MarginLeft, "margin-left")
		.AddParser(PropertyParseKeyword<"auto">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterShorthand(ShorthandId::Margin, "margin", "margin-top, margin-right, margin-bottom, margin-left", ShorthandType::Box);

	RegisterProperty(PropertyId::PaddingTop, "padding-top")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::PaddingRight, "padding-right")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::PaddingBottom, "padding-bottom")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::PaddingLeft, "padding-left")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterShorthand(ShorthandId::Padding, "padding", "padding-top, padding-right, padding-bottom, padding-left", ShorthandType::Box);

	RegisterProperty(PropertyId::Top, "top")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::Right, "right")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::Bottom, "bottom")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::Left, "left")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);

	RegisterProperty(PropertyId::Width, "width")
		.AddParser(PropertyParseKeyword<"auto">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::MinWidth, "min-width")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::MaxWidth, "max-width")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);

	RegisterProperty(PropertyId::Height, "height")
		.AddParser(PropertyParseKeyword<"auto">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::MinHeight, "min-height")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::MaxHeight, "max-height")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);

	RegisterProperty(PropertyId::ColumnGap, "column-gap")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::RowGap, "row-gap")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::Gap, "gap")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	
	RegisterProperty(PropertyId::AlignContent, "align-content")
		.AddParser(PropertyParseKeyword<"auto", "flex-start", "center", "flex-end", "stretch", "baseline", "space-between", "space-around", "space-evenly">);
	RegisterProperty(PropertyId::AlignItems, "align-items")
		.AddParser(PropertyParseKeyword<"auto", "flex-start", "center", "flex-end", "stretch", "baseline", "space-between", "space-around">);
	RegisterProperty(PropertyId::AlignSelf, "align-self")
		.AddParser(PropertyParseKeyword<"auto", "flex-start", "center", "flex-end", "stretch", "baseline", "space-between", "space-around">);
	RegisterProperty(PropertyId::Direction, "direction")
		.AddParser(PropertyParseKeyword<"inherit", "ltr", "rtl">);
	RegisterProperty(PropertyId::FlexDirection, "flex-direction")
		.AddParser(PropertyParseKeyword<"column", "column-reverse", "row", "row-reverse">);
	RegisterProperty(PropertyId::FlexWrap, "flex-wrap")
		.AddParser(PropertyParseKeyword<"nowrap", "wrap", "wrap-reverse">);
	RegisterProperty(PropertyId::JustifyContent, "justify-content")
		.AddParser(PropertyParseKeyword<"flex-start", "center", "flex-end", "space-between", "space-around", "space-evenly">);

	RegisterProperty(PropertyId::AspectRatio, "aspect-ratio")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Number>);
	RegisterProperty(PropertyId::Flex, "flex")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Number>);
	RegisterProperty(PropertyId::FlexBasis, "flex-basis")
		.AddParser(PropertyParseKeyword<"auto">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::FlexGrow, "flex-grow")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Number>);
	RegisterProperty(PropertyId::FlexShrink, "flex-shrink")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Number>);

	RegisterProperty(PropertyId::PointerEvents, "pointer-events", "auto")
		.AddParser(PropertyParseKeyword<"none", "auto">);
	RegisterProperty(PropertyId::ScrollLeft, "scroll-left", "0px")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::ScrollTop, "scroll-top", "0px")
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::Filter, "filter", "none")
		.AddParser(PropertyParseKeyword<"none", "gray">);
	PropertyVector properties;
	for (auto const& [id, value] : unparsed_default) {
		if (!ParsePropertyDeclaration(properties, id, value)) {
			auto kebabName = std::get<2>(propertyNames[(size_t)id]);
			Log::Message(Log::Level::Error, "property '%s' default value (%s) parse failed..", kebabName.data(), value.c_str());
		}
	}
	unparsed_default.clear();
	default_value = Style::Instance().Create(properties);
}

static StyleSheetSpecificationInstance* instance = nullptr;

bool StyleSheetSpecification::Initialise() {
	if (instance == nullptr) {
		Style::Initialise(InheritableProperties);
		instance = new StyleSheetSpecificationInstance();
		instance->RegisterProperties();
	}
	return true;
}

void StyleSheetSpecification::Shutdown() {
	if (instance != nullptr) {
		delete instance;
		Style::Shutdown();
	}
}

const Style::TableRef& StyleSheetSpecification::GetDefaultProperties() {
	return instance->GetDefaultProperties();
}

const PropertyIdSet & StyleSheetSpecification::GetInheritableProperties() {
	return instance->GetInheritableProperties();
}

bool StyleSheetSpecification::ParseDeclaration(PropertyIdSet& set, const std::string& property_name) {
	return instance->ParseDeclaration(set, property_name);
}

bool StyleSheetSpecification::ParseDeclaration(PropertyVector& vec, const std::string& property_name, const std::string& property_value) {
	return instance->ParseDeclaration(vec, property_name, property_value);
}

}
