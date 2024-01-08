#include <css/PropertyParserString.h>

namespace Rml {

PropertyView PropertyParserString::ParseValue(PropertyId id, const std::string& value) const {
	return { id, value };
}

}
