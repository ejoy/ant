#include <css/PropertyParserString.h>

namespace Rml {

Property PropertyParseString(PropertyId id, const std::string& value) {
	return { id, value };
}

}
