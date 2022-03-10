#include "../Include/RmlUi/ElementStyle.h"
#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/Document.h"
#include "../Include/RmlUi/ElementUtilities.h"
#include "../Include/RmlUi/FontEngineInterface.h"
#include "../Include/RmlUi/Log.h"
#include "../Include/RmlUi/Property.h"
#include "../Include/RmlUi/PropertyDefinition.h"
#include "../Include/RmlUi/PropertyDictionary.h"
#include "../Include/RmlUi/PropertyIdSet.h"
#include "../Include/RmlUi/StyleSheet.h"
#include "../Include/RmlUi/StyleSheetSpecification.h"
#include "../Include/RmlUi/Transform.h"
#include "../Include/RmlUi/ElementText.h"
#include "../Include/RmlUi/StringUtilities.h"
#include "ElementDefinition.h"
#include "PropertiesIterator.h"
#include <algorithm>
#include <numbers>

namespace Rml {
	
float ComputeProperty(FloatValue fv, Element* e) {
	static constexpr float PixelsPerInch = 96.0f;
	switch (fv.unit) {
	case Property::NUMBER:
	case Property::PX:
	case Property::RAD:
		return fv.value;
	case Property::EM:
		return fv.value * e->GetFontSize();
	case Property::REM:
		return fv.value * e->GetOwnerDocument()->GetBody()->GetFontSize();
	case Property::DEG:
		return fv.value * (std::numbers::pi_v<float> / 180.0f);
	case Property::VW:
		return fv.value * e->GetOwnerDocument()->GetDimensions().w * 0.01f;
	case Property::VH:
		return fv.value * e->GetOwnerDocument()->GetDimensions().h * 0.01f;
	case Property::VMIN: {
		auto const& size = e->GetOwnerDocument()->GetDimensions();
		return fv.value * std::min(size.w, size.h) * 0.01f;
	}
	case Property::VMAX: {
		auto const& size = e->GetOwnerDocument()->GetDimensions();
		return fv.value * std::max(size.w, size.h) * 0.01f;
	}
	case Property::INCH: // inch
		return fv.value * PixelsPerInch;
	case Property::CM: // centimeter
		return fv.value * PixelsPerInch * (1.0f / 2.54f);
	case Property::MM: // millimeter
		return fv.value * PixelsPerInch * (1.0f / 25.4f);
	case Property::PT: // point
		return fv.value * PixelsPerInch * (1.0f / 72.0f);
	case Property::PC: // pica
		return fv.value * PixelsPerInch * (1.0f / 6.0f);
	default:
		return 0.0f;
	}
}

float ComputePropertyW(FloatValue fv, Element* e) {
	if (fv.unit == Property::PERCENT) {
		return fv.value * e->GetMetrics().frame.size.w * 0.01f;
	}
	return ComputeProperty(fv, e);
}

float ComputePropertyH(FloatValue fv, Element* e) {
	if (fv.unit == Property::PERCENT) {
		return fv.value * e->GetMetrics().frame.size.h * 0.01f;
	}
	return ComputeProperty(fv, e);
}

float ComputeProperty(const Property* property, Element* e) {
	return ComputeProperty(property->ToFloatValue(), e);
}

float ComputePropertyW(const Property* property, Element* e) {
	return ComputePropertyW(property->ToFloatValue(), e);
}

float ComputePropertyH(const Property* property, Element* e) {
	return ComputePropertyH(property->ToFloatValue(), e);
}

ElementStyle::ElementStyle(Element* _element) {
	definition = nullptr;
	element = _element;
	definition_dirty = true;
}

const Property* ElementStyle::GetLocalProperty(PropertyId id) const {
	const Property* property = inline_properties.GetProperty(id);
	if (property)
		return property;
	if (definition)
		return definition->GetProperty(id);
	return nullptr;
}

const Property* ElementStyle::GetProperty(PropertyId id) const {
	const Property* local_property = GetLocalProperty(id);
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

const Property* ElementStyle::GetPropertyByDefinition(PropertyId id, const ElementDefinition* definition) const {
	const Property* property = definition->GetProperty(id);
	if (property)
		return property;
	property = inline_properties.GetProperty(id);
	if (property)
		return property;
	const PropertyDefinition* propertyDef = StyleSheetSpecification::GetProperty(id);
	if (!propertyDef)
		return nullptr;
	if (propertyDef->IsInherited()) {
		Element* parent = element->GetParentNode();
		while (parent) {
			const Property* parent_property = parent->GetStyle()->GetLocalProperty(id);
			if (parent_property)
				return parent_property;
			parent = parent->GetParentNode();
		}
	}
	return propertyDef->GetDefaultValue();
}

void ElementStyle::TransitionPropertyChanges(PropertyIdSet& properties, const ElementDefinition* new_definition) {
	const Property* transition_property = GetPropertyByDefinition(PropertyId::Transition, new_definition);
	if (!transition_property) {
		return;
	}
	auto transition_list = transition_property->GetTransitionList();
	if (transition_list.none) {
		return;
	}
	auto add_transition = [&](const Transition& transition) {
		const Property* from = GetProperty(transition.id);
		const Property* to = GetPropertyByDefinition(transition.id, new_definition);
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
	auto transition_list = transition_property->GetTransitionList();
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

		std::shared_ptr<ElementDefinition> new_definition;
		
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
					const Property* p1 = GetPropertyByDefinition(id, new_definition.get());
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

bool ElementStyle::SetPropertyImmediate(PropertyId id, const Property& property) {
	Property new_property = property;
	new_property.definition = StyleSheetSpecification::GetProperty(id);
	if (!new_property.definition)
		return false;
	inline_properties.SetProperty(id, new_property);
	DirtyProperty(id);
	return true;
}

void ElementStyle::RemoveProperty(PropertyId id) {
	int size_before = inline_properties.GetNumProperties();
	inline_properties.RemoveProperty(id);
	if (inline_properties.GetNumProperties() != size_before)
		DirtyProperty(id);
}

void ElementStyle::DirtyDefinition() {
	definition_dirty = true;
}

void ElementStyle::DirtyInheritedProperties() {
	dirty_properties |= StyleSheetSpecification::GetRegisteredInheritedProperties();
}

void ElementStyle::DirtyChildDefinitions() {
	for (int i = 0; i < element->GetNumChildren(); i++)
		element->GetChild(i)->GetStyle()->DirtyDefinition();
}

void ElementStyle::DirtyPropertiesWithUnitRecursive(Property::Unit unit) {
	for (auto it = Iterate(); !it.AtEnd(); ++it) {
		auto name_property_pair = *it;
		PropertyId id = name_property_pair.first;
		const Property& property = name_property_pair.second;
		if (property.unit & unit) {
			DirtyProperty(id);
		}
	}
	int num_children = element->GetNumChildren();
	for (int i = 0; i < num_children; ++i)
		element->GetChild(i)->GetStyle()->DirtyPropertiesWithUnitRecursive(unit);
}

bool ElementStyle::AnyPropertiesDirty() const {
	return !dirty_properties.Empty(); 
}

PropertiesIterator ElementStyle::Iterate() const {
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

void ElementStyle::DirtyProperty(PropertyId id) {
	dirty_properties.Insert(id);
}

void ElementStyle::DirtyProperties(const PropertyIdSet& properties) {
	dirty_properties |= properties;
}

PropertyIdSet ElementStyle::ComputeValues(Style::ComputedValues& values) {
	if (dirty_properties.Empty())
		return PropertyIdSet();

	bool dirty_em_properties = false;

	if (dirty_properties.Contains(PropertyId::FontSize)) {
		if (element->UpdataFontSize()) {
			dirty_em_properties = true;
			dirty_properties.Insert(PropertyId::LineHeight);
		}
	}

	for (auto it = Iterate(); !it.AtEnd(); ++it) {
		auto name_property_pair = *it;
		const PropertyId id = name_property_pair.first;
		const Property* p = &name_property_pair.second;

		if (dirty_em_properties && p->unit == Property::EM)
			dirty_properties.Insert(id);
		if (!dirty_properties.Contains(id)) {
			continue;
		}

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
			element->GetLayout().SetProperty(id, p, element);
			break;
		case PropertyId::BorderTopColor:
			values.border_color.top = p->GetColor();
			break;
		case PropertyId::BorderRightColor:
			values.border_color.right = p->GetColor();
			break;
		case PropertyId::BorderBottomColor:
			values.border_color.bottom = p->GetColor();
			break;
		case PropertyId::BorderLeftColor:
			values.border_color.left = p->GetColor();
			break;
		case PropertyId::BorderTopLeftRadius:
			values.border_radius.topLeft = p->ToFloatValue();
			break;
		case PropertyId::BorderTopRightRadius:
			values.border_radius.topRight = p->ToFloatValue();
			break;
		case PropertyId::BorderBottomRightRadius:
			values.border_radius.bottomRight = p->ToFloatValue();
			break;
		case PropertyId::BorderBottomLeftRadius:
			values.border_radius.bottomLeft = p->ToFloatValue();
			break;

		case PropertyId::BackgroundColor:
			values.background_color = p->GetColor();
			break;

		case PropertyId::Transition:
			values.transition = p->GetTransitionList();
			break;
		case PropertyId::Animation:
			values.animation = p->GetAnimationList();
			break;
		default:
			break;
		}
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
