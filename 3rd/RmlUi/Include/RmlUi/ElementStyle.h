#pragma once

#include "Property.h"

namespace Rml {

class Element;

float ComputeProperty(PropertyFloatValue value, Element* e);
float ComputePropertyW(PropertyFloatValue value, Element* e);
float ComputePropertyH(PropertyFloatValue value, Element* e);
float ComputeProperty(const Property* property, Element* e);
float ComputePropertyW(const Property* property, Element* e);
float ComputePropertyH(const Property* property, Element* e);

}
