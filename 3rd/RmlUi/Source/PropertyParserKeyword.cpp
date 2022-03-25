#include "PropertyParserKeyword.h"
#include "../Include/RmlUi/StringUtilities.h"
#include "../Include/RmlUi/Property.h"

namespace Rml {

std::optional<Property> PropertyParserKeyword::ParseValue(const std::string& value) const {
 	auto iterator = parameters.find(StringUtilities::ToLower(value));
	if (iterator == parameters.end())
		return {};
	return Property {iterator->second };
}

}
