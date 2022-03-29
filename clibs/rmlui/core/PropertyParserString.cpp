#include "PropertyParserString.h"
#include "core/Property.h"

namespace Rml {

std::optional<Property> PropertyParserString::ParseValue(const std::string& value) const {
	return Property {value};
}

}
