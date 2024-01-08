#include <css/PropertyParserKeyword.h>

namespace Rml {

PropertyView PropertyParserKeyword::ParseValue(PropertyId id, const std::string& value) const {
 	auto iterator = parameters.find(value);
	if (iterator == parameters.end())
		return {};
	return { id, iterator->second };
}

}
