#pragma once

#include <css/PropertyIdSet.h>
#include <css/PropertyVector.h>
#include <css/StyleCache.h>
#include <optional>

namespace Rml {

class PropertyParser;

class StyleSheetSpecification {
public:
	static bool Initialise();
	static void Shutdown();
	static Style::TableValue GetDefaultProperties();
	static const PropertyIdSet& GetInheritableProperties();
	static bool ParsePropertyDeclaration(PropertyIdSet& set, const std::string& property_name);
	static bool ParsePropertyDeclaration(PropertyVector& vec, const std::string& property_name, const std::string& property_value);
};

}
