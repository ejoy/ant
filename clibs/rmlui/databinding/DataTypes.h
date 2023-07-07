#pragma once

#include <functional>
#include <string>
#include <unordered_set>
#include <vector>

namespace Rml {

class Event;

using DirtyVariables = std::unordered_set<std::string>;

struct DataAddressEntry {
	DataAddressEntry(std::string name) : name(name), index(-1) { }
	DataAddressEntry(int index) : index(index) { }
	std::string name;
	int index;
};
using DataAddress = std::vector<DataAddressEntry>;

}
