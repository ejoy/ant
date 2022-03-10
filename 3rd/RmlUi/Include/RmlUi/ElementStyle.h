#pragma once

#include "Property.h"

namespace Rml {

class Element;

float ComputeProperty(FloatValue value, Element* e);
float ComputePropertyW(FloatValue value, Element* e);
float ComputePropertyH(FloatValue value, Element* e);
float ComputeProperty(const Property* property, Element* e);
float ComputePropertyW(const Property* property, Element* e);
float ComputePropertyH(const Property* property, Element* e);

}
