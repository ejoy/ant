#pragma once

#include <css/Property.h>

namespace Rml {

Property PropertyParseAnimation(PropertyId id, const std::string& value);
Property PropertyParseTransition(PropertyId id, const std::string& value);

}
