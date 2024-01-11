#pragma once

#include <css/PropertyIdSet.h>
#include <css/Property.h>
#include <css/StyleCache.h>

namespace Rml {

class StyleSheetSpecification {
public:
	static void Initialise();
	static void Shutdown();
	static const Style::TableRef& GetDefaultProperties();
	static const PropertyIdSet& GetInheritableProperties();
	static bool ParseDeclaration(PropertyIdSet& set, std::string_view property_name);
	static bool ParseDeclaration(PropertyVector& vec, PropertyId property_id, std::string_view property_value);
	static bool ParseDeclaration(PropertyVector& vec, std::string_view property_name, std::string_view property_value);
};

}
