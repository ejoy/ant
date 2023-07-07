#pragma once

#include <databinding/DataTypes.h>
#include <databinding/DataVariable.h>
#include <memory>
#include <string>
#include <unordered_map>
#include <unordered_set>

namespace Rml {

class Element;
class Node;

class DataModel {
public:
	DataModel();
	~DataModel();

	DataModel(const DataModel&) = delete;
	DataModel& operator=(const DataModel&) = delete;

	bool BindVariable(const std::string& name, DataVariable variable);

	void CleanDirty();
	void MarkDirty();
	bool IsDirty() const;
	void Update();

private:
	std::unordered_map<std::string, DataVariable> variables;
	bool dirty = false;
};

}
