#include "PropertyParserString.h"
#include "../Include/RmlUi/Property.h"

namespace Rml {

std::optional<Property> PropertyParserString::ParseValue(const std::string& value) const {
	return Property {value};
}

}
