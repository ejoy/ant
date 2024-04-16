#include <css/StyleSheetSpecification.h>
#include <css/StyleCache.h>
#include <css/PropertyIdSet.h>
#include <util/StringUtilities.h>
#include <css/PropertyParserNumber.h>
#include <css/PropertyParserAnimation.h>
#include <css/PropertyParserColour.h>
#include <css/PropertyParserKeyword.h>
#include <css/PropertyParserString.h>
#include <css/PropertyParserTransform.h>
#include <css/EnumName.h>
#include <css/StyleSheetDefaultValue.h>
#include <util/ConstexprMap.h>
#include <util/AlwaysFalse.h>
#include <core/Layout.h>
#include <core/ComputedValues.h>
#include <array>
#include <memory>
#include <optional>
#include <yoga/Yoga.h>
#include <core/Geometry.h>

namespace Rml {

using PropertyParser = Property (*)(PropertyId id, const std::string& value);
using PropertyDefinition = std::array<PropertyParser, 2>;

using ShorthandDefinitionFallThrough = std::vector<PropertyId>;
using ShorthandDefinitionBox = std::array<PropertyId, 4>;
using ShorthandDefinitionRecursiveRepeat = std::vector<ShorthandId>;
using ShorthandDefinition = std::variant<ShorthandDefinitionFallThrough, ShorthandDefinitionBox, ShorthandDefinitionRecursiveRepeat>;

template <typename E, size_t I, size_t N, typename Data>
static constexpr void MakeCssEnumName(Data&& data) {
	if constexpr (I < N) {
		data[2*I+0] = std::make_pair(CssEnumNameV<CssEnumNameStyle::Camel, static_cast<E>(I)>, static_cast<E>(I));
		data[2*I+1] = std::make_pair(CssEnumNameV<CssEnumNameStyle::Kebab, static_cast<E>(I)>, static_cast<E>(I));
		MakeCssEnumName<E, I+1, N>(data);
	}
}

template <typename E>
static consteval auto MakeCssEnumNames() {
	std::array<std::pair<std::string_view, E>, 2 * EnumCountV<E>> data;
	MakeCssEnumName<E, 0, EnumCountV<E>>(data);
	return MakeConstexprMap(data);
}

template <typename E, typename Value, size_t N>
static constexpr auto MakeEnumArray(const std::pair<E, Value> (&items)[N]) noexcept {
	std::array<Value, EnumCountV<E>> data = {};
	for (auto const& [k, v] : items) {
		data[(size_t)k] = v;
	}
	return data;
}

static constexpr PropertyIdSet InheritableProperties = (+[]{
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
})();
static_assert((InheritableProperties & LayoutProperties).empty());
static constexpr auto PropertyNames = MakeCssEnumNames<PropertyId>(); 
static constexpr auto ShorthandNames = MakeCssEnumNames<ShorthandId>();

static constexpr auto PropertyDefinitions = MakeEnumArray<PropertyId, PropertyDefinition>({
	{ PropertyId::BorderTopWidth, {
		PropertyParseNumber<PropertyParseNumberUnit::Length>,
	}},
	{ PropertyId::BorderRightWidth, {
		PropertyParseNumber<PropertyParseNumberUnit::Length>,
	}},
	{ PropertyId::BorderBottomWidth, {
		PropertyParseNumber<PropertyParseNumberUnit::Length>,
	}},
	{ PropertyId::BorderLeftWidth, {
		PropertyParseNumber<PropertyParseNumberUnit::Length>,
	}},

	{ PropertyId::BorderTopColor, {
		PropertyParseColour,
	}},
	{ PropertyId::BorderRightColor, {
		PropertyParseColour,
	}},
	{ PropertyId::BorderBottomColor, {
		PropertyParseColour,
	}},
	{ PropertyId::BorderLeftColor, {
		PropertyParseColour,
	}},

	{ PropertyId::BorderTopLeftRadius, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::BorderTopRightRadius, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::BorderBottomRightRadius, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::BorderBottomLeftRadius, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},

	{ PropertyId::ZIndex, {
		PropertyParseNumber<PropertyParseNumberUnit::Number>,
	}},

	{ PropertyId::LineHeight, {
		PropertyParseKeyword<"normal">,
		PropertyParseNumber<PropertyParseNumberUnit::Number>,
	}},

	{ PropertyId::Color, {
		PropertyParseColour,
	}},

	{ PropertyId::Opacity, {
		PropertyParseNumber<PropertyParseNumberUnit::Number>,
	}},

	{ PropertyId::FontStyle, {
		PropertyParseKeyword<Style::FontStyle>,
	}},
	{ PropertyId::FontWeight, {
		PropertyParseKeyword<Style::FontWeight>,
	}},
	{ PropertyId::FontSize, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::FontFamily, {
		PropertyParseString,
	}},

	{ PropertyId::TextAlign, {
		PropertyParseKeyword<Style::TextAlign>,
	}},
	{ PropertyId::WordBreak, {
		PropertyParseKeyword<Style::WordBreak>,
	}},

	{ PropertyId::TextDecorationLine, {
		PropertyParseKeyword<Style::TextDecorationLine>,
	}},
	{ PropertyId::TextDecorationColor, {
		PropertyParseKeyword<"currentColor">,
		PropertyParseColour,
	}},

	// Perspective and Transform specifications
	{ PropertyId::Perspective, {
		PropertyParseKeyword<"none">,
		PropertyParseNumber<PropertyParseNumberUnit::Length>,
	}},
	{ PropertyId::PerspectiveOriginX, {
		PropertyParseKeyword<Style::OriginX>,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::PerspectiveOriginY, {
		PropertyParseKeyword<Style::OriginY>,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::Transform, {
		PropertyParseTransform,
	}},
	{ PropertyId::TransformOriginX, {
		PropertyParseKeyword<Style::OriginX>,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::TransformOriginY, {
		PropertyParseKeyword<Style::OriginY>,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::TransformOriginZ, {
		PropertyParseNumber<PropertyParseNumberUnit::Length>,
	}},

	{ PropertyId::Transition, {
		PropertyParseTransition,
	}},
	{ PropertyId::Animation, {
		PropertyParseAnimation,
	}},

	{ PropertyId::BackgroundColor, {
		PropertyParseColour,
	}},
	{ PropertyId::BackgroundImage, {
		PropertyParseKeyword<"none">,
		PropertyParseString,
	}},
	{ PropertyId::BackgroundOrigin, {
		PropertyParseKeyword<Style::BoxType>,
	}},
	{ PropertyId::BackgroundSize, {
		PropertyParseKeyword<Style::BackgroundSize>,
	}},
	{ PropertyId::BackgroundSizeX, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::BackgroundSizeY, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},

	{ PropertyId::BackgroundPositionX, {
		PropertyParseKeyword<Style::OriginX>,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::BackgroundPositionY, {
		PropertyParseKeyword<Style::OriginY>,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},

	{ PropertyId::BackgroundRepeat, {
		PropertyParseKeyword<Style::BackgroundRepeat>,
	}},

	{ PropertyId::BackgroundFilter, {
		PropertyParseKeyword<"none">,
		PropertyParseColour,
	}},

	{ PropertyId::BackgroundLattice, {
		PropertyParseKeyword<Style::BackgroundLattice>,
	}},	
	{ PropertyId::BackgroundLatticeX1, {
		PropertyParseKeyword<Style::OriginX>,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::BackgroundLatticeY1, {
		PropertyParseKeyword<Style::OriginY>,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::BackgroundLatticeX2, {
		PropertyParseKeyword<Style::OriginX>,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::BackgroundLatticeY2, {
		PropertyParseKeyword<Style::OriginY>,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::BackgroundLatticeU, {
		PropertyParseKeyword<Style::OriginX>,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::BackgroundLatticeV, {
		PropertyParseKeyword<Style::OriginY>,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},

	{ PropertyId::TextShadowH, {
		PropertyParseNumber<PropertyParseNumberUnit::Length>,
	}},
	{ PropertyId::TextShadowV, {
		PropertyParseNumber<PropertyParseNumberUnit::Length>,
	}},
	{ PropertyId::TextShadowColor, {
		PropertyParseColour,
	}},

	{ PropertyId::_WebkitTextStrokeWidth, {
		PropertyParseNumber<PropertyParseNumberUnit::Length>,
	}},
	{ PropertyId::_WebkitTextStrokeColor, {
		PropertyParseColour,
	}},

	{ PropertyId::OutlineWidth, {
		PropertyParseNumber<PropertyParseNumberUnit::Length>,
	}},
	{ PropertyId::OutlineColor, {
		PropertyParseColour,
	}},

	{ PropertyId::PointerEvents, {
		PropertyParseKeyword<Style::PointerEvents>,
	}},
	{ PropertyId::ScrollLeft, {
		PropertyParseNumber<PropertyParseNumberUnit::Length>,
	}},
	{ PropertyId::ScrollTop, {
		PropertyParseNumber<PropertyParseNumberUnit::Length>,
	}},
	{ PropertyId::Filter, {
		PropertyParseKeyword<Style::Filter>,
	}},

	// flex layout
	{ PropertyId::Display, {
		PropertyParseKeyword<YGDisplay>,
	}},
	{ PropertyId::Overflow, {
		PropertyParseKeyword<YGOverflow>,
	}},
	{ PropertyId::Position, {
		PropertyParseKeyword<YGPositionType>,
	}},

	{ PropertyId::MarginTop, {
		PropertyParseKeyword<"auto">,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::MarginRight, {
		PropertyParseKeyword<"auto">,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::MarginBottom, {
		PropertyParseKeyword<"auto">,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::MarginLeft, {
		PropertyParseKeyword<"auto">,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},

	{ PropertyId::PaddingTop, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::PaddingRight, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::PaddingBottom, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::PaddingLeft, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},

	{ PropertyId::Top, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::Right, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::Bottom, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::Left, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},

	{ PropertyId::Width, {
		PropertyParseKeyword<"auto">,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::MinWidth, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::MaxWidth, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},

	{ PropertyId::Height, {
		PropertyParseKeyword<"auto">,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::MinHeight, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::MaxHeight, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},

	{ PropertyId::ColumnGap, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::RowGap, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::Gap, {
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	
	{ PropertyId::AlignContent, {
		PropertyParseKeyword<YGAlign>,
	}},
	{ PropertyId::AlignItems, {
		PropertyParseKeyword<YGAlign>,
	}},
	{ PropertyId::AlignSelf, {
		PropertyParseKeyword<YGAlign>,
	}},
	{ PropertyId::Direction, {
		PropertyParseKeyword<YGDirection>,
	}},
	{ PropertyId::FlexDirection, {
		PropertyParseKeyword<YGFlexDirection>,
	}},
	{ PropertyId::FlexWrap, {
		PropertyParseKeyword<YGWrap>,
	}},
	{ PropertyId::JustifyContent, {
		PropertyParseKeyword<YGJustify>,
	}},

	{ PropertyId::AspectRatio, {
		PropertyParseNumber<PropertyParseNumberUnit::Number>,
	}},
	{ PropertyId::Flex, {
		PropertyParseNumber<PropertyParseNumberUnit::Number>,
	}},
	{ PropertyId::FlexBasis, {
		PropertyParseKeyword<"auto">,
		PropertyParseNumber<PropertyParseNumberUnit::LengthPercent>,
	}},
	{ PropertyId::FlexGrow, {
		PropertyParseNumber<PropertyParseNumberUnit::Number>,
	}},
	{ PropertyId::FlexShrink, {
		PropertyParseNumber<PropertyParseNumberUnit::Number>,
	}},
});

// TODO: constexpr
static auto ShorthandDefinitions = MakeEnumArray<ShorthandId, ShorthandDefinition>({
	{ ShorthandId::BorderWidth, ShorthandDefinitionBox {
		PropertyId::BorderTopWidth,
		PropertyId::BorderRightWidth,
		PropertyId::BorderBottomWidth,
		PropertyId::BorderLeftWidth,
	}},
	{ ShorthandId::BorderColor, ShorthandDefinitionBox {
		PropertyId::BorderTopColor,
		PropertyId::BorderRightColor,
		PropertyId::BorderBottomColor,
		PropertyId::BorderLeftColor,
	}},
	{ ShorthandId::BorderTop, ShorthandDefinitionFallThrough {
		PropertyId::BorderTopWidth,
		PropertyId::BorderTopColor,
	}},
	{ ShorthandId::BorderRight, ShorthandDefinitionFallThrough {
		PropertyId::BorderRightWidth,
		PropertyId::BorderRightColor,
	}},
	{ ShorthandId::BorderBottom, ShorthandDefinitionFallThrough {
		PropertyId::BorderBottomWidth,
		PropertyId::BorderBottomColor,
	}},
	{ ShorthandId::BorderLeft, ShorthandDefinitionFallThrough {
		PropertyId::BorderLeftWidth,
		PropertyId::BorderLeftColor,
	}},
	{ ShorthandId::Border, ShorthandDefinitionRecursiveRepeat {
		ShorthandId::BorderTop,
		ShorthandId::BorderRight,
		ShorthandId::BorderBottom,
		ShorthandId::BorderLeft,
	}},
	{ ShorthandId::BorderRadius, ShorthandDefinitionBox {
		PropertyId::BorderTopLeftRadius,
		PropertyId::BorderTopRightRadius,
		PropertyId::BorderBottomRightRadius,
		PropertyId::BorderBottomLeftRadius,
	}},
	{ ShorthandId::Font, ShorthandDefinitionFallThrough {
		PropertyId::FontStyle,
		PropertyId::FontWeight,
		PropertyId::FontSize,
		PropertyId::FontFamily,
	}},
	{ ShorthandId::TextDecoration, ShorthandDefinitionFallThrough {
		PropertyId::TextDecorationLine,
		PropertyId::TextDecorationColor,
	}},
	{ ShorthandId::PerspectiveOrigin, ShorthandDefinitionFallThrough {
		PropertyId::PerspectiveOriginX,
		PropertyId::PerspectiveOriginY,
	}},
	{ ShorthandId::TransformOrigin, ShorthandDefinitionFallThrough {
		PropertyId::TransformOriginX,
		PropertyId::TransformOriginY,
		PropertyId::TransformOriginZ,
	}},
	{ ShorthandId::BackgroundSize, ShorthandDefinitionFallThrough {
		PropertyId::BackgroundSizeX,
		PropertyId::BackgroundSizeY,
	}},
	{ ShorthandId::BackgroundPosition, ShorthandDefinitionFallThrough {
		PropertyId::BackgroundPositionX,
		PropertyId::BackgroundPositionY,
	}},
	{ ShorthandId::Background, ShorthandDefinitionFallThrough {
		PropertyId::BackgroundImage,
		PropertyId::BackgroundPositionX,
		PropertyId::BackgroundPositionY,
		PropertyId::BackgroundSizeX,
		PropertyId::BackgroundSizeY,
	}},
	{ ShorthandId::BackgroundLattice, ShorthandDefinitionFallThrough {
		PropertyId::BackgroundLatticeX1,
		PropertyId::BackgroundLatticeY1,
		PropertyId::BackgroundLatticeX2,
		PropertyId::BackgroundLatticeY2,
		PropertyId::BackgroundLatticeU,
		PropertyId::BackgroundLatticeV,
	}},
	{ ShorthandId::TextShadow, ShorthandDefinitionFallThrough {
		PropertyId::TextShadowH,
		PropertyId::TextShadowV,
		PropertyId::TextShadowColor,
	}},
	{ ShorthandId::_WebkitTextStroke, ShorthandDefinitionFallThrough {
		PropertyId::_WebkitTextStrokeWidth,
		PropertyId::_WebkitTextStrokeColor,
	}},
	{ ShorthandId::Outline, ShorthandDefinitionFallThrough {
		PropertyId::OutlineWidth,
		PropertyId::OutlineColor,
	}},
	{ ShorthandId::Margin, ShorthandDefinitionBox {
		PropertyId::MarginTop,
		PropertyId::MarginRight,
		PropertyId::MarginBottom,
		PropertyId::MarginLeft,
	}},
	{ ShorthandId::Padding, ShorthandDefinitionBox {
		PropertyId::PaddingTop,
		PropertyId::PaddingRight,
		PropertyId::PaddingBottom,
		PropertyId::PaddingLeft,
	}},
});

template <typename MAP>
std::optional<typename MAP::mapped_type> MapGet(MAP const& map, std::string_view name)  {
	auto it = map.find(name);
	if (it != map.end())
		return it->second;
	return std::nullopt;
}

static bool ParsePropertyValues(std::vector<std::string>& values_list, std::string_view values, bool split_values) {
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

static Property ParseProperty(PropertyId id, const std::string& value) {
	auto& definition = PropertyDefinitions[(size_t)id];
	for (auto parser : definition) {
		if (!parser) {
			break;
		}
		auto prop = parser(id, value);
		if (prop) {
			return prop;
		}
	}
	return {};
}

static bool ParsePropertyDeclaration(PropertyVector& vec, PropertyId property_id, std::string_view property_value) {
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

static void ParseShorthandDeclaration(PropertyIdSet& set, ShorthandId shorthand_id) {
	const ShorthandDefinition& shorthand_definition = ShorthandDefinitions[(size_t)shorthand_id];
	std::visit([&](auto&& arg) {
		using T = std::decay_t<decltype(arg)>;
		if constexpr (std::is_same_v<T, ShorthandDefinitionFallThrough>) {
			for (auto id : arg) {
				set.insert(id);
			}
		}
		else if constexpr (std::is_same_v<T, ShorthandDefinitionBox>) {
			set.insert(arg[0]);
			set.insert(arg[1]);
			set.insert(arg[2]);
			set.insert(arg[3]);
		}
		else if constexpr (std::is_same_v<T, ShorthandDefinitionRecursiveRepeat>) {
			for (auto id : arg) {
				ParseShorthandDeclaration(set, id);
			}
		}
		else {
			static_assert(always_false_v<T>, "non-exhaustive visitor!");
		}
	}, shorthand_definition);
}

static bool ParseShorthandDeclaration(PropertyVector& vec, ShorthandId shorthand_id, const std::vector<std::string>& property_values);

static bool ParseShorthandDeclaration(PropertyVector& vec, ShorthandDefinitionFallThrough const& definition, const std::vector<std::string>& property_values) {
	size_t value_index = 0;
	size_t property_index = 0;
	for (; value_index < property_values.size() && property_index < definition.size(); property_index++) {
		auto id = definition[property_index];
		auto new_property = ParseProperty(id, property_values[value_index]);
		if (!new_property) {
			// This definition failed to parse; if we're falling through, try the next property. If there is no
			// next property, then abort!
			if (property_index + 1 < definition.size())
				continue;
			return false;
		}
		vec.emplace_back(new_property);
		// Increment the value index, unless we're replicating the last value and we're up to the last value.
		value_index++;
	}
	return true;
}

static bool ParseShorthandDeclaration(PropertyVector& vec, ShorthandDefinitionBox const& definition, const std::vector<std::string>& property_values) {
	// If this definition is a 'box'-style shorthand (x-top, x-right, x-bottom, x-left, etc) and there are fewer
	// than four values
	// This array tells which property index each side is parsed from
	std::array<int, 4> box_side_to_value_index = { 0,0,0,0 };
	switch (property_values.size()) {
	case 0:
		return false;
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
		box_side_to_value_index = { 0,1,2,3 };
		break;
	}

	for (size_t i = 0; i < 4; i++) {
		auto id = definition[i];
		int value_index = box_side_to_value_index[i];
		auto new_property = ParseProperty(id, property_values[value_index]);
		if (!new_property) {
			return false;
		}
		vec.emplace_back(new_property);
	}
	return true;
}

static bool ParseShorthandDeclaration(PropertyVector& vec, ShorthandDefinitionRecursiveRepeat const& definition, const std::vector<std::string>& property_values) {
	bool ok = true;
	for (auto id : definition) {
		ok &= ParseShorthandDeclaration(vec, id, property_values);
	}
	return ok;
}

static bool ParseShorthandDeclaration(PropertyVector& vec, ShorthandId shorthand_id, const std::vector<std::string>& property_values) {
	const ShorthandDefinition& shorthand_definition = ShorthandDefinitions[(size_t)shorthand_id];
	return std::visit([&](auto&& arg)->bool {
		return ParseShorthandDeclaration(vec, arg, property_values);
	}, shorthand_definition);
}

static bool ParseShorthandDeclaration(PropertyVector& vec, ShorthandId shorthand_id, std::string_view property_value) {
	std::vector<std::string> property_values;
	if (!ParsePropertyValues(property_values, property_value, true) || property_values.size() == 0) {
		return false;
	}
	return ParseShorthandDeclaration(vec, shorthand_id, property_values);
}
 
void StyleSheetSpecification::Initialise() {
	Style::Initialise(InheritableProperties);
	StyleSheetDefaultValue::Initialise();
}

void StyleSheetSpecification::Shutdown() {
	StyleSheetDefaultValue::Shutdown();
	Style::Shutdown();
}

const Style::TableRef& StyleSheetSpecification::GetDefaultProperties() {
	return StyleSheetDefaultValue::Get();
}

const PropertyIdSet& StyleSheetSpecification::GetInheritableProperties() {
	return InheritableProperties;
}

bool StyleSheetSpecification::ParseDeclaration(PropertyIdSet& set, std::string_view property_name) {
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

bool StyleSheetSpecification::ParseDeclaration(PropertyVector& vec, PropertyId property_id, std::string_view property_value) {
	return ParsePropertyDeclaration(vec, property_id, property_value);
}

bool StyleSheetSpecification::ParseDeclaration(PropertyVector& vec, std::string_view property_name, std::string_view property_value) {
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

}
