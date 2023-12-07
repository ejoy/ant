#include <css/PropertyParserKeyword.h>
#include <css/Property.h>

namespace Rml {

std::optional<Property> PropertyParserKeyword::ParseValue(const std::string& value) const {
 	auto iterator = parameters.find(value);
	if (iterator == parameters.end())
		return std::nullopt;
	return Property {iterator->second };
}

}
