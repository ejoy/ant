#pragma once

#include "Types.h"
#include <string>
#include <vector>

namespace Rml {

class DataControllerInstancer;
class DataViewInstancer;
class Element;

class Factory {
public:
	static bool Initialise();
	static void Shutdown();
	static void RegisterDataViewInstancer(DataViewInstancer* instancer, const std::string& type_name, bool is_structural_view = false);
	static void RegisterDataControllerInstancer(DataControllerInstancer* instancer, const std::string& type_name);
	static DataViewPtr InstanceDataView(const std::string& type_name, Element* element, bool is_structural_view);
	static DataControllerPtr InstanceDataController(Element* element, const std::string& type_name);
	static bool IsStructuralDataView(const std::string& type_name);
	static const std::vector<std::string>& GetStructuralDataViewAttributeNames();
};

}
