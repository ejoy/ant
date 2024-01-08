#pragma once

#include <optional>
#include <string>
#include <css/PropertyView.h>

namespace Rml {

class PropertyParser {
public:
	virtual ~PropertyParser() {}
	virtual PropertyView ParseValue(PropertyId id, const std::string& value) const = 0;
};

}
