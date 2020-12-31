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

#include "ElementStyle.h"
#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/ElementDocument.h"
#include "../Include/RmlUi/ElementUtilities.h"
#include "../Include/RmlUi/FontEngineInterface.h"
#include "../Include/RmlUi/Log.h"
#include "../Include/RmlUi/Math.h"
#include "../Include/RmlUi/Property.h"
#include "../Include/RmlUi/PropertyDefinition.h"
#include "../Include/RmlUi/PropertyDictionary.h"
#include "../Include/RmlUi/PropertyIdSet.h"
#include "../Include/RmlUi/StyleSheet.h"
#include "../Include/RmlUi/StyleSheetSpecification.h"
#include "../Include/RmlUi/TransformPrimitive.h"
#include "../Include/RmlUi/ElementText.h"
#include "ElementBackgroundImage.h"
#include "ElementDefinition.h"
#include "ComputeProperty.h"
#include "PropertiesIterator.h"
#include <algorithm>


namespace Rml {

ElementStyle::ElementStyle(Element* _element)
{
	definition = nullptr;
	element = _element;

	definition_dirty = true;
}

const ElementDefinition* ElementStyle::GetDefinition() const
{
	return definition.get();
}

// Returns one of this element's properties.
const Property* ElementStyle::GetLocalProperty(PropertyId id, const ElementDefinition* definition) const {
	const Property* property = inline_properties.GetProperty(id);
	if (property)
		return property;
	if (definition)
		return definition->GetProperty(id);
	return nullptr;
}

// Returns one of this element's properties.
const Property* ElementStyle::GetProperty(PropertyId id, const ElementDefinition* definition) const
{
	const Property* local_property = GetLocalProperty(id, definition);
	if (local_property)
		return local_property;
	const PropertyDefinition* property = StyleSheetSpecification::GetProperty(id);
	if (!property)
		return nullptr;
	if (property->IsInherited()) {
		Element* parent = element->GetParentNode();
		while (parent) {
			const Property* parent_property = parent->GetStyle()->GetLocalProperty(id);
			if (parent_property)
				return parent_property;
			parent = parent->GetParentNode();
		}
	}
	return property->GetDefaultValue();
}

void ElementStyle::TransitionPropertyChanges(PropertyIdSet& properties, const ElementDefinition* new_definition) {
	const Property* transition_property = GetProperty(PropertyId::Transition, new_definition);
	if (!transition_property) {
		return;
	}
	auto transition_list = transition_property->Get<TransitionList>();
	if (transition_list.none) {
		return;
	}
	auto add_transition = [&](const Transition& transition) {
		const Property* from = GetProperty(transition.id);
		const Property* to = GetProperty(transition.id, new_definition);
		if (from && to && (from->unit == to->unit) && (*from != *to)) {
			return element->StartTransition(transition, *from, *to, true);
		}
		return false;
	};
	if (transition_list.all) {
		Transition transition = transition_list.transitions[0];
		for (auto it = properties.begin(); it != properties.end(); ) {
			transition.id = *it;
			if (add_transition(transition))
				it = properties.Erase(it);
			else
				++it;
		}
	}
	else {
		for (auto& transition : transition_list.transitions) {
			if (properties.Contains(transition.id)) {
				if (add_transition(transition))
					properties.Erase(transition.id);
			}
		}
	}
}

bool ElementStyle::TransitionPropertyChanges(PropertyId id, const Property& property) {
	const Property* transition_property = GetProperty(PropertyId::Transition);
	if (!transition_property) {
		return false;
	}
	auto transition_list = transition_property->Get<TransitionList>();
	if (transition_list.none) {
		return false;
	}
	auto add_transition = [&](const Transition& transition) {
		const Property* from = GetProperty(id);
		if (from && (from->unit == property.unit) && (*from != property)) {
			return element->StartTransition(transition, *from, property, false);
		}
		return false;
	};
	if (transition_list.all) {
		Transition transition = transition_list.transitions[0];
		transition.id = id;
		return add_transition(transition);
	}
	else {
		bool ok = false;
		for (auto& transition : transition_list.transitions) {
			if (transition.id == id) {
				ok = ok || add_transition(transition);
			}
		}
		return ok;
	}
}

void ElementStyle::UpdateDefinition() {
	if (definition_dirty) {
		definition_dirty = false;

		SharedPtr<ElementDefinition> new_definition;
		
		if (auto& style_sheet = element->GetStyleSheet()) {
			new_definition = style_sheet->GetElementDefinition(element);
		}
		
		// Switch the property definitions if the definition has changed.
		if (new_definition != definition) {
			PropertyIdSet changed_properties;
			
			if (definition)
				changed_properties = definition->GetPropertyIds();

			if (new_definition)
				changed_properties |= new_definition->GetPropertyIds();

			if (definition && new_definition) {
				for (PropertyId id : changed_properties) {
					const Property* p0 = GetProperty(id);
					const Property* p1 = GetProperty(id);
					if (p0 && p1 && *p0 == *p1)
						changed_properties.Erase(id);
				}
				if (!changed_properties.Empty()) {
					TransitionPropertyChanges(changed_properties, new_definition.get());
				}
			}
			definition = new_definition;
			DirtyProperties(changed_properties);
		}

		// Even if the definition was not changed, the child definitions may have changed as a result of anything that
		// could change the definition of this element, such as a new pseudo class.
		DirtyChildDefinitions();
	}
}



// Sets or removes a pseudo-class on the element.
void ElementStyle::SetPseudoClass(const String& pseudo_class, bool activate)
{
	bool changed = false;

	if (activate)
		changed = pseudo_classes.insert(pseudo_class).second;
	else
		changed = (pseudo_classes.erase(pseudo_class) == 1);

	if (changed)
	{
		DirtyDefinition();
	}
}

// Checks if a specific pseudo-class has been set on the element.
bool ElementStyle::IsPseudoClassSet(const String& pseudo_class) const
{
	return (pseudo_classes.count(pseudo_class) == 1);
}

const PseudoClassList& ElementStyle::GetActivePseudoClasses() const
{
	return pseudo_classes;
}

// Sets or removes a class on the element.
void ElementStyle::SetClass(const String& class_name, bool activate)
{
	StringList::iterator class_location = std::find(classes.begin(), classes.end(), class_name);

	if (activate)
	{
		if (class_location == classes.end())
		{
			classes.push_back(class_name);
			DirtyDefinition();
		}
	}
	else
	{
		if (class_location != classes.end())
		{
			classes.erase(class_location);
			DirtyDefinition();
		}
	}
}

// Checks if a class is set on the element.
bool ElementStyle::IsClassSet(const String& class_name) const
{
	return std::find(classes.begin(), classes.end(), class_name) != classes.end();
}

// Specifies the entire list of classes for this element. This will replace any others specified.
void ElementStyle::SetClassNames(const String& class_names)
{
	classes.clear();
	StringUtilities::ExpandString(classes, class_names, ' ');
	DirtyDefinition();
}

// Returns the list of classes specified for this element.
String ElementStyle::GetClassNames() const
{
	String class_names;
	for (size_t i = 0; i < classes.size(); i++)
	{
		if (i != 0)
		{
			class_names += " ";
		}
		class_names += classes[i];
	}

	return class_names;
}

bool ElementStyle::SetProperty(PropertyId id, const Property& property) {
	Property new_property = property;
	new_property.definition = StyleSheetSpecification::GetProperty(id);
	if (!new_property.definition)
		return false;
	if (!TransitionPropertyChanges(id, new_property)) {
		inline_properties.SetProperty(id, new_property);
		DirtyProperty(id);
	}
	return true;
}

bool ElementStyle::SetPropertyImmediate(PropertyId id, const Property& property)
{
	Property new_property = property;
	new_property.definition = StyleSheetSpecification::GetProperty(id);
	if (!new_property.definition)
		return false;
	inline_properties.SetProperty(id, new_property);
	DirtyProperty(id);
	return true;
}

// Removes a local property override on the element.
void ElementStyle::RemoveProperty(PropertyId id)
{
	int size_before = inline_properties.GetNumProperties();
	inline_properties.RemoveProperty(id);

	if(inline_properties.GetNumProperties() != size_before)
		DirtyProperty(id);
}

// Returns one of this element's properties.
const Property* ElementStyle::GetProperty(PropertyId id) const
{
	return GetProperty(id, definition.get());
}

// Returns one of this element's properties.
const Property* ElementStyle::GetLocalProperty(PropertyId id) const
{
	return GetLocalProperty(id, definition.get());
}

const PropertyMap& ElementStyle::GetLocalStyleProperties() const
{
	return inline_properties.GetProperties();
}

float ElementStyle::ResolveNumericProperty(const Property* property, float base_value) const
{
	if (!property || !(property->unit & (Property::NUMBER_LENGTH_PERCENT | Property::ANGLE)))
		return 0.0f;

	if (property->unit & Property::NUMBER)
		return property->Get<float>() * base_value;
	else if (property->unit & Property::PERCENT)
		return property->Get<float>() * base_value * 0.01f;
	else if (property->unit & Property::ANGLE)
		return ComputeAngle(*property);

	const float dp_ratio = ElementUtilities::GetDensityIndependentPixelRatio(element);
	const float font_size = element->GetComputedValues().font_size;

	auto doc = element->GetOwnerDocument();
	const float doc_font_size = (doc ? doc->GetComputedValues().font_size : DefaultComputedValues.font_size);

	float result = ComputeLength(property, font_size, doc_font_size, dp_ratio);

	return result;
}

void ElementStyle::DirtyDefinition()
{
	definition_dirty = true;
}

void ElementStyle::DirtyInheritedProperties()
{
	dirty_properties |= StyleSheetSpecification::GetRegisteredInheritedProperties();
}

void ElementStyle::DirtyChildDefinitions()
{
	for (int i = 0; i < element->GetNumChildren(); i++)
		element->GetChild(i)->GetStyle()->DirtyDefinition();
}

void ElementStyle::DirtyPropertiesWithUnitRecursive(Property::Unit unit)
{
	// Dirty all the properties of this element that use the unit.
	for (auto it = Iterate(); !it.AtEnd(); ++it)
	{
		auto name_property_pair = *it;
		PropertyId id = name_property_pair.first;
		const Property& property = name_property_pair.second;
		if (property.unit == unit)
			DirtyProperty(id);
	}

	// Now dirty all of our descendant's properties that use the unit.
	int num_children = element->GetNumChildren();
	for (int i = 0; i < num_children; ++i)
		element->GetChild(i)->GetStyle()->DirtyPropertiesWithUnitRecursive(unit);
}

bool ElementStyle::AnyPropertiesDirty() const 
{
	return !dirty_properties.Empty(); 
}

PropertiesIterator ElementStyle::Iterate() const {
	// Note: Value initialized iterators are only guaranteed to compare equal in C++14, and only for iterators satisfying the ForwardIterator requirements.
#ifdef _MSC_VER
	// Null forward iterator supported since VS 2015
	static_assert(_MSC_VER >= 1900, "Visual Studio 2015 or higher required, see comment.");
#else
	static_assert(__cplusplus >= 201402L, "C++14 or higher required, see comment.");
#endif

	const PropertyMap& property_map = inline_properties.GetProperties();
	auto it_style_begin = property_map.begin();
	auto it_style_end = property_map.end();

	PropertyMap::const_iterator it_definition{}, it_definition_end{};
	if (definition)
	{
		const PropertyMap& definition_properties = definition->GetProperties().GetProperties();
		it_definition = definition_properties.begin();
		it_definition_end = definition_properties.end();
	}
	return PropertiesIterator(it_style_begin, it_style_end, it_definition, it_definition_end);
}

// Sets a single property as dirty.
void ElementStyle::DirtyProperty(PropertyId id)
{
	dirty_properties.Insert(id);
}

// Sets a list of properties as dirty.
void ElementStyle::DirtyProperties(const PropertyIdSet& properties)
{
	dirty_properties |= properties;
}

PropertyIdSet ElementStyle::ComputeValues(Style::ComputedValues& values, const Style::ComputedValues* parent_values, const Style::ComputedValues* document_values, bool values_are_default_initialized, float dp_ratio)
{
	if (dirty_properties.Empty())
		return PropertyIdSet();

	// Generally, this is how it works:
	//   1. Assign default values (clears any removed properties)
	//   2. Inherit inheritable values from parent
	//   3. Assign any local properties (from inline style or stylesheet)
	//   4. Dirty properties in children that are inherited

	const float font_size_before = values.font_size;
	const Style::LineHeight line_height_before = values.line_height;

	// The next flag is just a small optimization, if the element was just created we don't need to copy all the default values.
	if (!values_are_default_initialized) {
		// This needs to be done in case some properties were removed and thus not in our local style anymore.
		// If we skipped this, the old dirty value would be unmodified, instead, now it is set to its default value.
		// Strictly speaking, we only really need to do this for the dirty values, and only non-inherited. However,
		// it seems assigning the whole thing is faster in most cases.
		values = DefaultComputedValues;
	}

	bool dirty_em_properties = false;

	// Always do font-size first if dirty, because of em-relative values
	if (dirty_properties.Contains(PropertyId::FontSize)) {
		if (auto p = GetLocalProperty(PropertyId::FontSize))
			values.font_size = ComputeFontsize(*p, values, parent_values, document_values, dp_ratio);
		else if (parent_values)
			values.font_size = parent_values->font_size;
		
		if (font_size_before != values.font_size)
		{
			dirty_em_properties = true;
			dirty_properties.Insert(PropertyId::LineHeight);
		}
	}
	else {
		values.font_size = font_size_before;
	}

	const float font_size = values.font_size;
	const float document_font_size = (document_values ? document_values->font_size : DefaultComputedValues.font_size);


	// Since vertical-align depends on line-height we compute this before iteration
	if(dirty_properties.Contains(PropertyId::LineHeight)) {
		if (auto p = GetLocalProperty(PropertyId::LineHeight)) {
			values.line_height = ComputeLineHeight(p, font_size, document_font_size, dp_ratio);
		}
		else if (parent_values) {
			// Line height has a special inheritance case for numbers/percent: they inherit them directly instead of computed length, but for lengths, they inherit the length.
			// See CSS specs for details. Percent is already converted to number.
			if (parent_values->line_height.inherit_type == Style::LineHeight::Number)
				values.line_height = Style::LineHeight(font_size * parent_values->line_height.inherit_value, Style::LineHeight::Number, parent_values->line_height.inherit_value);
			else
				values.line_height = parent_values->line_height;
		}
	}
	else {
		values.line_height = line_height_before;
	}


	if (parent_values) {
		// Inherited properties are copied here, but may be overwritten below by locally defined properties
		// Line-height and font-size are computed above
		values.clip = parent_values->clip;
		values.color = parent_values->color;
		values.opacity = parent_values->opacity;
		values.font_family = parent_values->font_family;
		values.font_style = parent_values->font_style;
		values.font_weight = parent_values->font_weight;
		values.font_face_handle = parent_values->font_face_handle;
		values.text_align = parent_values->text_align;
		values.text_decoration = parent_values->text_decoration;
		values.text_transform = parent_values->text_transform;
		values.white_space = parent_values->white_space;
		values.word_break = parent_values->word_break;
		values.focus = parent_values->focus;
		values.pointer_events = parent_values->pointer_events;

		values.text_shadow = parent_values->text_shadow;
		values.text_stroke = parent_values->text_stroke;
	}


	for (auto it = Iterate(); !it.AtEnd(); ++it) {
		auto name_property_pair = *it;
		const PropertyId id = name_property_pair.first;
		const Property* p = &name_property_pair.second;

		if (dirty_em_properties && p->unit == Property::EM)
			dirty_properties.Insert(id);

		using namespace Style;

		switch (id) {
		case PropertyId::Left:
		case PropertyId::Top:
		case PropertyId::Right:
		case PropertyId::Bottom:
		case PropertyId::MarginLeft:
		case PropertyId::MarginTop:
		case PropertyId::MarginRight:
		case PropertyId::MarginBottom:
		case PropertyId::PaddingLeft:
		case PropertyId::PaddingTop:
		case PropertyId::PaddingRight:
		case PropertyId::PaddingBottom:
		case PropertyId::BorderLeftWidth:
		case PropertyId::BorderTopWidth:
		case PropertyId::BorderRightWidth:
		case PropertyId::BorderBottomWidth:
		case PropertyId::Height:
		case PropertyId::Width:
		case PropertyId::MaxHeight:
		case PropertyId::MinHeight:
		case PropertyId::MaxWidth:
		case PropertyId::MinWidth:
		case PropertyId::Position:
		case PropertyId::Display:
		case PropertyId::Overflow:
		case PropertyId::AlignContent:
		case PropertyId::AlignItems:
		case PropertyId::AlignSelf:
		case PropertyId::Direction:
		case PropertyId::FlexDirection:
		case PropertyId::FlexWrap:
		case PropertyId::JustifyContent:
		case PropertyId::AspectRatio:
		case PropertyId::Flex:
		case PropertyId::FlexBasis:
		case PropertyId::FlexGrow:
		case PropertyId::FlexShrink:
			element->GetLayout().SetProperty(id, p, font_size, document_font_size, dp_ratio);
			break;
		}

		switch (id) {
		case PropertyId::Display:
			values.display = (Display)p->Get<int>();
			break;
		case PropertyId::Overflow:
			values.overflow = (Overflow)p->Get< int >();
			break;

		case PropertyId::BorderTopColor:
			values.border_top_color = p->Get<Colourb>();
			break;
		case PropertyId::BorderRightColor:
			values.border_right_color = p->Get<Colourb>();
			break;
		case PropertyId::BorderBottomColor:
			values.border_bottom_color = p->Get<Colourb>();
			break;
		case PropertyId::BorderLeftColor:
			values.border_left_color = p->Get<Colourb>();
			break;
		case PropertyId::BorderTopLeftRadius:
			values.border_top_left_radius = ComputeLength(p, font_size, document_font_size, dp_ratio);
			break;
		case PropertyId::BorderTopRightRadius:
			values.border_top_right_radius = ComputeLength(p, font_size, document_font_size, dp_ratio);
			break;
		case PropertyId::BorderBottomRightRadius:
			values.border_bottom_right_radius = ComputeLength(p, font_size, document_font_size, dp_ratio);
			break;
		case PropertyId::BorderBottomLeftRadius:
			values.border_bottom_left_radius = ComputeLength(p, font_size, document_font_size, dp_ratio);
			break;

		case PropertyId::ZIndex:
			values.z_index = (p->unit == Property::KEYWORD ? ZIndex(ZIndex::Auto) : ZIndex(ZIndex::Number, p->Get<float>()));
			break;

		case PropertyId::LineHeight:
			// (Line-height computed above)
			break;

		case PropertyId::Clip:
			values.clip = ComputeClip(p);
			break;
		case PropertyId::Visibility:
			values.visibility = (Visibility)p->Get<int>();
			break;

		case PropertyId::BackgroundColor:
			values.background_color = p->Get<Colourb>();
			break;
		case PropertyId::BackgroundImage:
			values.background_image = p->Get<String>();
			break;

		case PropertyId::Color:
			values.color = p->Get<Colourb>();
			break;
		case PropertyId::ImageColor:
			values.image_color = p->Get<Colourb>();
			break;
		case PropertyId::Opacity:
			values.opacity = p->Get<float>();
			break;

		case PropertyId::FontFamily:
			values.font_family = StringUtilities::ToLower(p->Get<String>());
			values.font_face_handle = 0;
			break;
		case PropertyId::FontStyle:
			values.font_style = (FontStyle)p->Get< int >();
			values.font_face_handle = 0;
			break;
		case PropertyId::FontWeight:
			values.font_weight = (FontWeight)p->Get< int >();
			values.font_face_handle = 0;
			break;
		case PropertyId::FontSize:
			// (font-size computed above)
			values.font_face_handle = 0;
			break;

		case PropertyId::TextAlign:
			values.text_align = (TextAlign)p->Get<int>();
			break;
		case PropertyId::TextDecoration:
			values.text_decoration = (TextDecoration)p->Get<int>();
			break;
		case PropertyId::TextTransform:
			values.text_transform = (TextTransform)p->Get<int>();
			break;
		case PropertyId::WhiteSpace:
			values.white_space = (WhiteSpace)p->Get<int>();
			break;
		case PropertyId::WordBreak:
			values.word_break = (WordBreak)p->Get<int>();
			break;

		case PropertyId::Drag:
			values.drag = (Drag)p->Get<int>();
			break;
		case PropertyId::Focus:
			values.focus = (Focus)p->Get<int>();
			break;
		case PropertyId::PointerEvents:
			values.pointer_events = (PointerEvents)p->Get<int>();
			break;

		case PropertyId::Perspective:
			values.perspective = ComputeLength(p, font_size, document_font_size, dp_ratio);
			break;
		case PropertyId::PerspectiveOriginX:
			values.perspective_origin_x = ComputeOrigin(p, font_size, document_font_size, dp_ratio);
			break;
		case PropertyId::PerspectiveOriginY:
			values.perspective_origin_y = ComputeOrigin(p, font_size, document_font_size, dp_ratio);
			break;

		case PropertyId::Transform:
			values.transform = p->Get<TransformPtr>();
			break;
		case PropertyId::TransformOriginX:
			values.transform_origin_x = ComputeOrigin(p, font_size, document_font_size, dp_ratio);
			break;
		case PropertyId::TransformOriginY:
			values.transform_origin_y = ComputeOrigin(p, font_size, document_font_size, dp_ratio);
			break;
		case PropertyId::TransformOriginZ:
			values.transform_origin_z = ComputeLength(p, font_size, document_font_size, dp_ratio);
			break;

		case PropertyId::Transition:
			values.transition = p->Get<TransitionList>();
			break;
		case PropertyId::Animation:
			values.animation = p->Get<AnimationList>();
			break;

		case PropertyId::TextShadowH:
			if (!values.text_shadow) {
				values.text_shadow = TextShadow{};
			}
			values.text_shadow->offset_h = ComputeLength(p, font_size, document_font_size, dp_ratio);
			break;
		case PropertyId::TextShadowV:
			if (!values.text_shadow) {
				values.text_shadow = TextShadow{};
			}
			values.text_shadow->offset_v = ComputeLength(p, font_size, document_font_size, dp_ratio);
			break;
		case PropertyId::TextShadowColor:
			if (!values.text_shadow) {
				values.text_shadow = TextShadow{};
			}
			values.text_shadow->color = p->Get<Colourb>();
			break;
		case PropertyId::TextStrokeWidth:
			if (!values.text_stroke) {
				values.text_stroke = TextStroke{};
			}
			values.text_stroke->width = ComputeLength(p, font_size, document_font_size, dp_ratio);
			break;
		case PropertyId::TextStrokeColor:
			if (!values.text_stroke) {
				values.text_stroke = TextStroke{};
			}
			values.text_stroke->color = p->Get<Colourb>();
			break;

		// Invalid properties
		case PropertyId::Invalid:
		case PropertyId::NumDefinedIds:
		case PropertyId::MaxNumIds:
			break;
		}
	}

	// The font-face handle is nulled when local font properties are set. In that case we need to retrieve a new handle.
	if (!values.font_face_handle) {
		values.font_face_handle = GetFontEngineInterface()->GetFontFaceHandle(values.font_family, values.font_style, values.font_weight, (int)values.font_size);
	}

	// Next, pass inheritable dirty properties onto our children
	PropertyIdSet dirty_inherited_properties = (dirty_properties & StyleSheetSpecification::GetRegisteredInheritedProperties());
	if (!dirty_inherited_properties.Empty()) {
		for (int i = 0; i < element->GetNumChildren(); i++) {
			auto child = element->GetChild(i);
			child->GetStyle()->dirty_properties |= dirty_inherited_properties;
		}
	}
	
	PropertyIdSet result(std::move(dirty_properties));
	dirty_properties.Clear();
	return result;
}

} // namespace Rml
