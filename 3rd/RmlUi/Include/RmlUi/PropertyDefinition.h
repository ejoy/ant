#pragma once

#include "Property.h"
#include "PropertyParser.h"
#include <optional>

namespace Rml {

class PropertyDefinition final {
public:
	PropertyDefinition(PropertyId id, bool inherited);
	PropertyDefinition(PropertyId id, const std::string& unparsed_default, bool inherited);
	PropertyDefinition(const PropertyDefinition &) = delete; 
	PropertyDefinition& operator=(const PropertyDefinition &) = delete;
	~PropertyDefinition();
	PropertyDefinition&            AddParser(const std::string& parser_name, const std::string& parser_parameters = "");
	std::optional<Property>        ParseValue(const std::string& value) const;
	const std::optional<Property>& GetDefaultValue() const;
	bool                           IsInherited() const;
	PropertyId                     GetId() const;

private:
	PropertyId id;
	std::optional<Property> default_value;
	std::string unparsed_default;
	bool inherited;
	struct ParserState {
		PropertyParser* parser;
		ParameterMap parameters;
	};
	std::vector< ParserState > parsers;
};

}
