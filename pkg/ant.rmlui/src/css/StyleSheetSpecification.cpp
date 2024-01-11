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
#include <util/ConstexprMap.h>
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

template <typename E, size_t I, size_t N, typename Data>
static constexpr void GetPropertyName(Data&& data) {
	if constexpr (I < N) {
		data[2*I+0] = std::make_pair(PropertyNameV<PropertyNameStyle::Camel, static_cast<E>(I)>, static_cast<E>(I));
		data[2*I+1] = std::make_pair(PropertyNameV<PropertyNameStyle::Kebab, static_cast<E>(I)>, static_cast<E>(I));
		GetPropertyName<E, I+1, N>(data);
	}
}

template <typename E>
static consteval auto GetPropertyNames() {
	std::array<std::pair<std::string_view, E>, 2 * EnumCountV<E>> data;
	GetPropertyName<E, 0, EnumCountV<E>>(data);
	return data;
}
static constexpr auto PropertyNames = MakeConstexprMap(GetPropertyNames<PropertyId>());
static constexpr auto ShorthandNames = MakeConstexprMap(GetPropertyNames<ShorthandId>());
static constexpr auto UnparsedDefaultValue = MakeConstexprMap<PropertyId, std::string_view>({
	{ PropertyId::BorderTopWidth, "0px" },
	{ PropertyId::BorderRightWidth, "0px" },
	{ PropertyId::BorderBottomWidth, "0px" },
	{ PropertyId::BorderLeftWidth, "0px" },
	{ PropertyId::BorderTopColor, "transparent" },
	{ PropertyId::BorderRightColor, "transparent" },
	{ PropertyId::BorderBottomColor, "transparent" },
	{ PropertyId::BorderLeftColor, "transparent" },
	{ PropertyId::BorderTopLeftRadius, "0px" },
	{ PropertyId::BorderTopRightRadius, "0px" },
	{ PropertyId::BorderBottomRightRadius, "0px" },
	{ PropertyId::BorderBottomLeftRadius, "0px" },
	{ PropertyId::ZIndex, "0" },
	{ PropertyId::LineHeight, "normal" },
	{ PropertyId::Color, "white" },
	{ PropertyId::Opacity, "1" },
	{ PropertyId::FontFamily, "" },
	{ PropertyId::FontStyle, "normal" },
	{ PropertyId::FontWeight, "normal" },
	{ PropertyId::FontSize, "12px" },
	{ PropertyId::TextAlign, "left" },
	{ PropertyId::WordBreak, "normal" },
	{ PropertyId::TextDecorationLine, "none" },
	{ PropertyId::TextDecorationColor, "currentColor" },
	{ PropertyId::Perspective, "none" },
	{ PropertyId::PerspectiveOriginX, "50%" },
	{ PropertyId::PerspectiveOriginY, "50%" },
	{ PropertyId::Transform, "none" },
	{ PropertyId::TransformOriginX, "50%" },
	{ PropertyId::TransformOriginY, "50%" },
	{ PropertyId::TransformOriginZ, "0px" },
	{ PropertyId::Transition, "none" },
	{ PropertyId::Animation, "none" },
	{ PropertyId::BackgroundColor, "transparent" },
	{ PropertyId::BackgroundImage, "none" },
	{ PropertyId::BackgroundOrigin, "padding-box" },
	{ PropertyId::BackgroundSize, "unset" },
	{ PropertyId::BackgroundSizeX, "0px" },
	{ PropertyId::BackgroundSizeY, "0px" },
	{ PropertyId::BackgroundPositionX, "0px" },
	{ PropertyId::BackgroundPositionY, "0px" },
	{ PropertyId::BackgroundLattice, "auto" },
	{ PropertyId::BackgroundLatticeX1, "0px" },
	{ PropertyId::BackgroundLatticeY1, "0px" },
	{ PropertyId::BackgroundLatticeX2, "0px" },
	{ PropertyId::BackgroundLatticeY2, "0px" },
	{ PropertyId::BackgroundLatticeU, "0px" },
	{ PropertyId::BackgroundLatticeV, "0px" },
	{ PropertyId::BackgroundRepeat, "repeat" },
	{ PropertyId::BackgroundFilter, "none" },
	{ PropertyId::TextShadowH, "0px" },
	{ PropertyId::TextShadowV, "0px" },
	{ PropertyId::TextShadowColor, "white" },
	{ PropertyId::_WebkitTextStrokeWidth, "0px" },
	{ PropertyId::_WebkitTextStrokeColor, "white" },
	{ PropertyId::OutlineWidth, "0px" },
	{ PropertyId::OutlineColor, "white" },
	{ PropertyId::PointerEvents, "auto" },
	{ PropertyId::ScrollLeft, "0px" },
	{ PropertyId::ScrollTop, "0px" },
	{ PropertyId::Filter, "none" },
});

struct StyleSheetSpecificationInstance {
	void RegisterProperties();

	bool RegisterShorthand(ShorthandId id, const std::string& shorthand_name, const std::string& property_names, ShorthandType type);

	template <typename... Parser>
	PropertyRegister RegisterProperty(PropertyId id/*, Parser&&... parser*/) {
		//properties[(size_t)id] = { { parser... } };
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
	Style::TableRef default_value;
};

PropertyRegister& PropertyRegister::AddParser(PropertyParser new_parser) {
	definition.parsers.push_back(new_parser);
	return *this;
}

template <typename MAP>
std::optional<typename MAP::mapped_type> MapGet(MAP const& map, std::string_view name)  {
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
		auto property_id = MapGet(PropertyNames, name);
		if (property_id) {
			// We have a valid property
			property_shorthand.items.emplace_back(*property_id);
			continue;
		}
		else {
			// Otherwise, we must be a shorthand
			auto shorthand_id = MapGet(ShorthandNames, name);
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
	auto property_id = MapGet(PropertyNames, property_name);
	if (property_id) {
		set.insert(*property_id);
		return true;
	}
	auto shorthand_id = MapGet(ShorthandNames, property_name);
	if (shorthand_id) {
		ParseShorthandDeclaration(set, *shorthand_id);
		return true;
	}
	return false;
}

bool StyleSheetSpecificationInstance::ParseDeclaration(PropertyVector& vec, const std::string& property_name, const std::string& property_value) const {
	auto property_id = MapGet(PropertyNames, property_name);
	if (property_id) {
		if (ParsePropertyDeclaration(vec, *property_id, property_value)) {
			return true;
		}
	}
	auto shorthand_id = MapGet(ShorthandNames, property_name);
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

void StyleSheetSpecificationInstance::RegisterProperties() {
	RegisterProperty(PropertyId::BorderTopWidth)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::BorderRightWidth)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::BorderBottomWidth)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::BorderLeftWidth)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterShorthand(ShorthandId::BorderWidth, "border-width", "border-top-width, border-right-width, border-bottom-width, border-left-width", ShorthandType::Box);

	RegisterProperty(PropertyId::BorderTopColor)
		.AddParser(PropertyParseColour);
	RegisterProperty(PropertyId::BorderRightColor)
		.AddParser(PropertyParseColour);
	RegisterProperty(PropertyId::BorderBottomColor)
		.AddParser(PropertyParseColour);
	RegisterProperty(PropertyId::BorderLeftColor)
		.AddParser(PropertyParseColour);
	RegisterShorthand(ShorthandId::BorderColor, "border-color", "border-top-color, border-right-color, border-bottom-color, border-left-color", ShorthandType::Box);

	RegisterShorthand(ShorthandId::BorderTop, "border-top", "border-top-width, border-top-color", ShorthandType::FallThrough);
	RegisterShorthand(ShorthandId::BorderRight, "border-right", "border-right-width, border-right-color", ShorthandType::FallThrough);
	RegisterShorthand(ShorthandId::BorderBottom, "border-bottom", "border-bottom-width, border-bottom-color", ShorthandType::FallThrough);
	RegisterShorthand(ShorthandId::BorderLeft, "border-left", "border-left-width, border-left-color", ShorthandType::FallThrough);
	RegisterShorthand(ShorthandId::Border, "border", "border-top, border-right, border-bottom, border-left", ShorthandType::RecursiveRepeat);

	RegisterProperty(PropertyId::BorderTopLeftRadius)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BorderTopRightRadius)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BorderBottomRightRadius)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BorderBottomLeftRadius)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterShorthand(ShorthandId::BorderRadius, "border-radius", "border-top-left-radius, border-top-right-radius, border-bottom-right-radius, border-bottom-left-radius", ShorthandType::Box);

	RegisterProperty(PropertyId::ZIndex)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Number>);

	RegisterProperty(PropertyId::LineHeight)
		.AddParser(PropertyParseKeyword<"normal">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Number>);

	RegisterProperty(PropertyId::Color)
		.AddParser(PropertyParseColour);

	RegisterProperty(PropertyId::Opacity)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Number>);

	RegisterProperty(PropertyId::FontFamily)
		.AddParser(PropertyParseString);
	RegisterProperty(PropertyId::FontStyle)
		.AddParser(PropertyParseKeyword<"normal", "italic">);
	RegisterProperty(PropertyId::FontWeight)
		.AddParser(PropertyParseKeyword<"normal", "bold">);
	RegisterProperty(PropertyId::FontSize)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterShorthand(ShorthandId::Font, "font", "font-style, font-weight, font-size, font-family", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::TextAlign)
		.AddParser(PropertyParseKeyword<"left", "right", "center", "justify">);
	RegisterProperty(PropertyId::WordBreak)
		.AddParser(PropertyParseKeyword<"normal", "break-all", "break-word">);

	RegisterProperty(PropertyId::TextDecorationLine)
		.AddParser(PropertyParseKeyword<"none", "underline", "overline", "line-through">);
	RegisterProperty(PropertyId::TextDecorationColor)
		.AddParser(PropertyParseKeyword<"currentColor">)
		.AddParser(PropertyParseColour);
	RegisterShorthand(ShorthandId::TextDecoration, "text-decoration", "text-decoration-line, text-decoration-color", ShorthandType::FallThrough);
	
	// Perspective and Transform specifications
	RegisterProperty(PropertyId::Perspective)
		.AddParser(PropertyParseKeyword<"none">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::PerspectiveOriginX)
		.AddParser(PropertyParseKeyword<"left", "center", "right">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::PerspectiveOriginY)
		.AddParser(PropertyParseKeyword<"top", "center", "bottom">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterShorthand(ShorthandId::PerspectiveOrigin, "perspective-origin", "perspective-origin-x, perspective-origin-y", ShorthandType::FallThrough);
	RegisterProperty(PropertyId::Transform)
		.AddParser(PropertyParseTransform);
	RegisterProperty(PropertyId::TransformOriginX)
		.AddParser(PropertyParseKeyword<"left", "center", "right">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::TransformOriginY)
		.AddParser(PropertyParseKeyword<"top", "center", "bottom">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::TransformOriginZ)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterShorthand(ShorthandId::TransformOrigin, "transform-origin", "transform-origin-x, transform-origin-y, transform-origin-z", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::Transition)
		.AddParser(PropertyParseTransition);
	RegisterProperty(PropertyId::Animation)
		.AddParser(PropertyParseAnimation);

	RegisterProperty(PropertyId::BackgroundColor)
		.AddParser(PropertyParseColour);
	RegisterProperty(PropertyId::BackgroundImage)
		.AddParser(PropertyParseKeyword<"none">)
		.AddParser(PropertyParseString);
	RegisterProperty(PropertyId::BackgroundOrigin)
		.AddParser(PropertyParseKeyword<"padding-box", "border-box", "content-box">);
	RegisterProperty(PropertyId::BackgroundSize)
		.AddParser(PropertyParseKeyword<"unset", "auto", "cover", "contain">);
	RegisterProperty(PropertyId::BackgroundSizeX)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BackgroundSizeY)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterShorthand(ShorthandId::BackgroundSize, "background-size", "background-size-x, background-size-y", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::BackgroundPositionX)
		.AddParser(PropertyParseKeyword<"left", "center", "right">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BackgroundPositionY)
		.AddParser(PropertyParseKeyword<"top", "center", "bottom">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterShorthand(ShorthandId::BackgroundPosition, "background-position", "background-position-x, background-position-y", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::BackgroundLattice)
		.AddParser(PropertyParseKeyword<"auto", "cover", "contain">);	
	RegisterProperty(PropertyId::BackgroundLatticeX1)
		.AddParser(PropertyParseKeyword<"left", "center", "right">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BackgroundLatticeY1)
		.AddParser(PropertyParseKeyword<"top", "center", "bottom">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BackgroundLatticeX2)
		.AddParser(PropertyParseKeyword<"left", "center", "right">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BackgroundLatticeY2)
		.AddParser(PropertyParseKeyword<"top", "center", "bottom">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BackgroundLatticeU)
		.AddParser(PropertyParseKeyword<"top", "center", "bottom">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::BackgroundLatticeV)
		.AddParser(PropertyParseKeyword<"top", "center", "bottom">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterShorthand(ShorthandId::BackgroundLattice, "background-lattice", "background-lattice-x1, background-lattice-y1, background-lattice-x2, background-lattice-y2, background-lattice-u, background-lattice-v", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::BackgroundRepeat)
		.AddParser(PropertyParseKeyword<"repeat", "repeat-x", "repeat-y", "no-repeat">);
	RegisterProperty(PropertyId::BackgroundFilter)
		.AddParser(PropertyParseKeyword<"none">)
		.AddParser(PropertyParseColour);
	RegisterShorthand(ShorthandId::Background, "background", "background-image, background-position-x, background-position-y, background-size-x, background-size-y", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::TextShadowH)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::TextShadowV)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::TextShadowColor)
		.AddParser(PropertyParseColour);
	RegisterShorthand(ShorthandId::TextShadow, "text-shadow", "text-shadow-h, text-shadow-v, text-shadow-color", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::_WebkitTextStrokeWidth)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::_WebkitTextStrokeColor)
		.AddParser(PropertyParseColour);
	RegisterShorthand(ShorthandId::_WebkitTextStroke, "-webkit-text-stroke", "-webkit-text-stroke-width, -webkit-text-stroke-color", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::OutlineWidth)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::OutlineColor)
		.AddParser(PropertyParseColour);
	RegisterShorthand(ShorthandId::Outline, "outline", "outline-width, outline-color", ShorthandType::FallThrough);

	RegisterProperty(PropertyId::PointerEvents)
		.AddParser(PropertyParseKeyword<"none", "auto">);
	RegisterProperty(PropertyId::ScrollLeft)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::ScrollTop)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::Filter)
		.AddParser(PropertyParseKeyword<"none", "gray">);

	// flex layout
	RegisterProperty(PropertyId::Display)
		.AddParser(PropertyParseKeyword<"flex", "none">);
	RegisterProperty(PropertyId::Overflow)
		.AddParser(PropertyParseKeyword<"visible", "hidden", "scroll">);
	RegisterProperty(PropertyId::Position)
		.AddParser(PropertyParseKeyword<"static", "relative", "absolute">);

	RegisterProperty(PropertyId::MarginTop)
		.AddParser(PropertyParseKeyword<"auto">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::MarginRight)
		.AddParser(PropertyParseKeyword<"auto">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::MarginBottom)
		.AddParser(PropertyParseKeyword<"auto">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::MarginLeft)
		.AddParser(PropertyParseKeyword<"auto">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterShorthand(ShorthandId::Margin, "margin", "margin-top, margin-right, margin-bottom, margin-left", ShorthandType::Box);

	RegisterProperty(PropertyId::PaddingTop)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::PaddingRight)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::PaddingBottom)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::PaddingLeft)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterShorthand(ShorthandId::Padding, "padding", "padding-top, padding-right, padding-bottom, padding-left", ShorthandType::Box);

	RegisterProperty(PropertyId::Top)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::Right)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::Bottom)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::Left)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);

	RegisterProperty(PropertyId::Width)
		.AddParser(PropertyParseKeyword<"auto">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::MinWidth)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::MaxWidth)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);

	RegisterProperty(PropertyId::Height)
		.AddParser(PropertyParseKeyword<"auto">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::MinHeight)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::MaxHeight)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);

	RegisterProperty(PropertyId::ColumnGap)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::RowGap)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	RegisterProperty(PropertyId::Gap)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Length>);
	
	RegisterProperty(PropertyId::AlignContent)
		.AddParser(PropertyParseKeyword<"auto", "flex-start", "center", "flex-end", "stretch", "baseline", "space-between", "space-around", "space-evenly">);
	RegisterProperty(PropertyId::AlignItems)
		.AddParser(PropertyParseKeyword<"auto", "flex-start", "center", "flex-end", "stretch", "baseline", "space-between", "space-around">);
	RegisterProperty(PropertyId::AlignSelf)
		.AddParser(PropertyParseKeyword<"auto", "flex-start", "center", "flex-end", "stretch", "baseline", "space-between", "space-around">);
	RegisterProperty(PropertyId::Direction)
		.AddParser(PropertyParseKeyword<"inherit", "ltr", "rtl">);
	RegisterProperty(PropertyId::FlexDirection)
		.AddParser(PropertyParseKeyword<"column", "column-reverse", "row", "row-reverse">);
	RegisterProperty(PropertyId::FlexWrap)
		.AddParser(PropertyParseKeyword<"nowrap", "wrap", "wrap-reverse">);
	RegisterProperty(PropertyId::JustifyContent)
		.AddParser(PropertyParseKeyword<"flex-start", "center", "flex-end", "space-between", "space-around", "space-evenly">);

	RegisterProperty(PropertyId::AspectRatio)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Number>);
	RegisterProperty(PropertyId::Flex)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Number>);
	RegisterProperty(PropertyId::FlexBasis)
		.AddParser(PropertyParseKeyword<"auto">)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>);
	RegisterProperty(PropertyId::FlexGrow)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Number>);
	RegisterProperty(PropertyId::FlexShrink)
		.AddParser(PropertyParseNumber<PropertyParseNumberUnit::Number>);
	PropertyVector properties;
	for (auto const& [id, value] : UnparsedDefaultValue) {
		if (!ParsePropertyDeclaration(properties, id, std::string { value.data(), value.size() })) {
			for (auto const& [prop_name, prop_id] : PropertyNames) {
				if (prop_id == id) {
					Log::Message(Log::Level::Error, "property '%s' default value (%s) parse failed..", prop_name.data(), value.data());
					break;
				}
			}
		}
	}
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
