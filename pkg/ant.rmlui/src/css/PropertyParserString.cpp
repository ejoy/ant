#include <css/PropertyParserString.h>

namespace Rml {

Property PropertyParserString::ParseValue(PropertyId id, const std::string& value) const {
	return { id, value };
}

}
