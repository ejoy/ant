#pragma once

#include <core/Types.h>
#include <core/PropertyIdSet.h>

namespace Rml {

class PropertyDefinition;
class PropertyParser;

class StyleSheetSpecification {
public:
	static bool Initialise();
	static void Shutdown();
	static PropertyParser* GetParser(const std::string& parser_name);
	static PropertyParser* GetKeywordParser(const std::string& parser_parameters);
	static const PropertyDefinition* GetPropertyDefinition(PropertyId id);
	static const PropertyIdSet& GetRegisteredInheritedProperties();
	static bool ParsePropertyDeclaration(PropertyIdSet& set, const std::string& property_name);
	static bool ParsePropertyDeclaration(PropertyDictionary& dictionary, const std::string& property_name, const std::string& property_value);
};

}
