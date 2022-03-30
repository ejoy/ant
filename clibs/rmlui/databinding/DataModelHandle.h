#pragma once

#include <databinding/DataTypes.h>
#include <databinding/DataVariable.h>

namespace Rml {

class DataModel;

class DataModelHandle {
public:
	DataModelHandle(DataModel* model = nullptr);
	bool IsVariableDirty(const std::string& variable_name);
	void DirtyVariable(const std::string& variable_name);
	explicit operator bool() { return model; }

private:
	DataModel* model;
};

class DataModelConstructor {
public:
	DataModelConstructor();
	DataModelConstructor(DataModel* model);
	DataModelHandle GetModelHandle() const;
	bool BindEventCallback(const std::string& name, DataEventFunc event_func);
	bool BindVariable(const std::string& name, DataVariable data_variable);
	explicit operator bool() { return model; }

private:
	DataModel* model;
};

}
