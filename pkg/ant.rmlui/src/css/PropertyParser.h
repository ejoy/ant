#pragma once

#include <optional>
#include <string>
#include <css/Property.h>

namespace Rml {

class PropertyParser {
public:
	virtual ~PropertyParser() {}
	virtual Property ParseValue(PropertyId id, const std::string& value) const = 0;
};

}
