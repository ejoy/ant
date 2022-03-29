#include "PropertyParserKeyword.h"
#include "core/StringUtilities.h"
#include "core/Property.h"

namespace Rml {

std::optional<Property> PropertyParserKeyword::ParseValue(const std::string& value) const {
 	auto iterator = parameters.find(StringUtilities::ToLower(value));
	if (iterator == parameters.end())
		return {};
	return Property {iterator->second };
}

}
