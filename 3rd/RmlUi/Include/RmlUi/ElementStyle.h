#pragma once

#include "ComputedValues.h"
#include "Types.h"
#include "PropertyIdSet.h"
#include "PropertyDictionary.h"

namespace Rml {

class ElementDefinition;
class PropertiesIterator;

class ElementStyle {
public:
	ElementStyle(Element* element);
	void UpdateDefinition();
	bool SetProperty(PropertyId id, const Property& property);
	bool SetPropertyImmediate(PropertyId id, const Property& property);
	void RemoveProperty(PropertyId id);
	const Property* GetProperty(PropertyId id) const;
	const Property* GetLocalProperty(PropertyId id) const;
	void DirtyDefinition();
	void DirtyInheritedProperties();
	void DirtyPropertiesWithUnitRecursive(Property::Unit unit);
	bool AnyPropertiesDirty() const;
	PropertyIdSet ComputeValues(Style::ComputedValues& values);
	PropertiesIterator Iterate() const;

private:
	void DirtyChildDefinitions();
	void DirtyProperty(PropertyId id);
	void DirtyProperties(const PropertyIdSet& properties);

	const Property* GetPropertyByDefinition(PropertyId id, const ElementDefinition* definition) const;
	void TransitionPropertyChanges(PropertyIdSet & properties, const ElementDefinition * new_definition);
	bool TransitionPropertyChanges(PropertyId id, const Property& property);

	Element* element;
	PropertyDictionary inline_properties;
	std::shared_ptr<ElementDefinition> definition;
	bool definition_dirty;
	PropertyIdSet dirty_properties;
};

float ComputeProperty(FloatValue value, Element* e);
float ComputePropertyW(FloatValue value, Element* e);
float ComputePropertyH(FloatValue value, Element* e);
float ComputeProperty(const Property* property, Element* e);
float ComputePropertyW(const Property* property, Element* e);
float ComputePropertyH(const Property* property, Element* e);

}
