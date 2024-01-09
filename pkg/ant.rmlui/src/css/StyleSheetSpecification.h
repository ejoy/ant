#pragma once

#include <css/PropertyIdSet.h>
#include <css/Property.h>
#include <css/StyleCache.h>

namespace Rml {

class StyleSheetSpecification {
public:
	static bool Initialise();
	static void Shutdown();
	static const Style::TableRef& GetDefaultProperties();
	static const PropertyIdSet& GetInheritableProperties();
	static bool ParseDeclaration(PropertyIdSet& set, const std::string& property_name);
	static bool ParseDeclaration(PropertyVector& vec, const std::string& property_name, const std::string& property_value);
};

}
