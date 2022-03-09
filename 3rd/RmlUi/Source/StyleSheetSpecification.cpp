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

#include "../Include/RmlUi/StyleSheetSpecification.h"
#include "../Include/RmlUi/PropertyIdSet.h"
#include "../Include/RmlUi/PropertyDefinition.h"
#include "../Include/RmlUi/Log.h"
#include "PropertyParserNumber.h"
#include "PropertyParserAnimation.h"
#include "PropertyParserColour.h"
#include "PropertyParserKeyword.h"
#include "PropertyParserString.h"
#include "PropertyParserTransform.h"
#include "PropertyShorthandDefinition.h"
#include "IdNameMap.h"

namespace Rml {

static StyleSheetSpecification* instance = nullptr;

struct DefaultStyleSheetParsers {
	PropertyParserNumber number = PropertyParserNumber(Property::NUMBER);
	PropertyParserNumber length = PropertyParserNumber(Property::LENGTH, Property::PX);
	PropertyParserNumber length_percent = PropertyParserNumber(Property::LENGTH_PERCENT, Property::PX);
	PropertyParserNumber number_length_percent = PropertyParserNumber(Property::NUMBER_LENGTH_PERCENT, Property::PX);
	PropertyParserNumber angle = PropertyParserNumber(Property::RAD | Property::DEG, Property::RAD);
	PropertyParserKeyword keyword = PropertyParserKeyword();
	PropertyParserString string = PropertyParserString();
	PropertyParserAnimation animation = PropertyParserAnimation(PropertyParserAnimation::ANIMATION_PARSER);
	PropertyParserAnimation transition = PropertyParserAnimation(PropertyParserAnimation::TRANSITION_PARSER);
	PropertyParserColour color = PropertyParserColour();
	PropertyParserTransform transform = PropertyParserTransform();
};

StyleSheetSpecification::StyleSheetSpecification()
	: properties()
{
	assert(instance == nullptr);
	instance = this;

	default_parsers.reset(new DefaultStyleSheetParsers);
}

StyleSheetSpecification::~StyleSheetSpecification()
{
	assert(instance == this);
	instance = nullptr;
}

PropertyDefinition& StyleSheetSpecification::RegisterProperty(PropertyId id, const std::string& property_name, bool inherited) {
	return properties.RegisterProperty(id, property_name, inherited);
}

PropertyDefinition& StyleSheetSpecification::RegisterProperty(PropertyId id, const std::string& property_name, const std::string& default_value, bool inherited) {
	return properties.RegisterProperty(id, property_name, inherited, default_value);
}

ShorthandId StyleSheetSpecification::RegisterShorthand(ShorthandId id, const std::string& shorthand_name, const std::string& property_names, ShorthandType type)
{
	return properties.RegisterShorthand(shorthand_name, property_names, type, id);
}

bool StyleSheetSpecification::Initialise()
{
	if (instance == nullptr)
	{
		new StyleSheetSpecification();

		instance->RegisterDefaultParsers();
		instance->RegisterDefaultProperties();
	}

	return true;
}

void StyleSheetSpecification::Shutdown()
{
	if (instance != nullptr)
	{
		delete instance;
	}
}

// Registers a parser for use in property definitions.
bool StyleSheetSpecification::RegisterParser(const std::string& parser_name, PropertyParser* parser)
{
	ParserMap::iterator iterator = instance->parsers.find(parser_name);
	if (iterator != instance->parsers.end())
	{
		Log::Message(Log::Level::Warning, "Parser with name %s already exists!", parser_name.c_str());
		return false;
	}

	instance->parsers[parser_name] = parser;
	return true;
}

// Returns the parser registered with a specific name.
PropertyParser* StyleSheetSpecification::GetParser(const std::string& parser_name)
{
	ParserMap::iterator iterator = instance->parsers.find(parser_name);
	if (iterator == instance->parsers.end())
		return nullptr;

	return (*iterator).second;
}

// Returns a property definition.
const PropertyDefinition* StyleSheetSpecification::GetProperty(const std::string& property_name)
{
	return instance->properties.GetProperty(property_name);
}

const PropertyDefinition* StyleSheetSpecification::GetProperty(PropertyId id)
{
	return instance->properties.GetProperty(id);
}

const PropertyIdSet& StyleSheetSpecification::GetRegisteredProperties()
{
	return instance->properties.GetRegisteredProperties();
}

const PropertyIdSet & StyleSheetSpecification::GetRegisteredInheritedProperties()
{
	return instance->properties.GetRegisteredInheritedProperties();
}

// Returns a shorthand definition.
const ShorthandDefinition* StyleSheetSpecification::GetShorthand(const std::string& shorthand_name)
{
	return instance->properties.GetShorthand(shorthand_name);
}

const ShorthandDefinition* StyleSheetSpecification::GetShorthand(ShorthandId id)
{
	return instance->properties.GetShorthand(id);
}

bool StyleSheetSpecification::ParsePropertyDeclaration(PropertyIdSet& set, const std::string& property_name)
{
	return instance->properties.ParsePropertyDeclaration(set, property_name);
}

bool StyleSheetSpecification::ParsePropertyDeclaration(PropertyDictionary& dictionary, const std::string& property_name, const std::string& property_value)
{
	return instance->properties.ParsePropertyDeclaration(dictionary, property_name, property_value);
}

PropertyId StyleSheetSpecification::GetPropertyId(const std::string& property_name)
{
	return instance->properties.property_map->GetId(property_name);
}

ShorthandId StyleSheetSpecification::GetShorthandId(const std::string& shorthand_name)
{
	return instance->properties.shorthand_map->GetId(shorthand_name);
}

const std::string& StyleSheetSpecification::GetPropertyName(PropertyId id)
{
	return instance->properties.property_map->GetName(id);
}

const std::string& StyleSheetSpecification::GetShorthandName(ShorthandId id)
{
	return instance->properties.shorthand_map->GetName(id);
}

PropertyIdSet StyleSheetSpecification::GetShorthandUnderlyingProperties(ShorthandId id)
{
	PropertyIdSet result;
	const ShorthandDefinition* shorthand = instance->properties.GetShorthand(id);
	if (!shorthand)
		return result;

	for (auto& item : shorthand->items)
	{
		if (item.type == ShorthandItemType::Property)
		{
			result.Insert(item.property_id);
		}
		else if (item.type == ShorthandItemType::Shorthand)
		{
			// When we have a shorthand pointing to another shorthands, call us recursively. Add the union of the previous result and new properties.
			result |= GetShorthandUnderlyingProperties(item.shorthand_id);
		}
	}
	return result;
}

const PropertySpecification& StyleSheetSpecification::GetPropertySpecification()
{
	return instance->properties;
}

// Registers RmlUi's default parsers.
void StyleSheetSpecification::RegisterDefaultParsers()
{
	RegisterParser("number", &default_parsers->number);
	RegisterParser("length", &default_parsers->length);
	RegisterParser("length_percent", &default_parsers->length_percent);
	RegisterParser("number_length_percent", &default_parsers->number_length_percent);
	RegisterParser("angle", &default_parsers->angle);
	RegisterParser("keyword", &default_parsers->keyword);
	RegisterParser("string", &default_parsers->string);
	RegisterParser("animation", &default_parsers->animation);
	RegisterParser("transition", &default_parsers->transition);
	RegisterParser("color", &default_parsers->color);
	RegisterParser("transform", &default_parsers->transform);
}


// Registers RmlUi's default style properties.
void StyleSheetSpecification::RegisterDefaultProperties()
{
	/* 
		Style property specifications (ala RCSS).

		Note: Whenever keywords or default values are changed, make sure its computed value is
		changed correspondingly, see `ComputedValues.h`.

		When adding new properties, it may be desirable to add it to the computed values as well.
		Then, make sure to resolve it as appropriate in `ElementStyle.cpp`.

	*/

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
	RegisterProperty(PropertyId::ScrollLeft, "scroll-left", "0", false)
		.AddParser("number");
	RegisterProperty(PropertyId::ScrollTop, "scroll-top", "0", false)
		.AddParser("number");
}

} // namespace Rml
