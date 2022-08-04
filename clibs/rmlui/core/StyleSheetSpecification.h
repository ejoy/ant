#pragma once

#include <core/PropertyIdSet.h>
#include <core/PropertyVector.h>
#include <core/StyleCache.h>
#include <optional>

namespace Rml {

class PropertyParser;

class StyleSheetSpecification {
public:
	static bool Initialise();
	static void Shutdown();
	static Style::PropertyMap GetDefaultProperties();
	static const PropertyIdSet& GetInheritedProperties();
	static bool ParsePropertyDeclaration(PropertyIdSet& set, const std::string& property_name);
	static bool ParsePropertyDeclaration(PropertyVector& vec, const std::string& property_name, const std::string& property_value);
};

}
