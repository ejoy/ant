#pragma once

#include <core/Variant.h>
#include <functional>
#include <string>
#include <unordered_set>
#include <vector>

namespace Rml {

class VariableDefinition;
class DataModelHandle;
class DataVariable;
class Event;

using DataEventFunc = std::function<void(DataModelHandle, Event&, const std::vector<Variant>&)>;
using DirtyVariables = std::unordered_set<std::string>;

struct DataAddressEntry {
	DataAddressEntry(std::string name) : name(name), index(-1) { }
	DataAddressEntry(int index) : index(index) { }
	std::string name;
	int index;
};
using DataAddress = std::vector<DataAddressEntry>;

}
