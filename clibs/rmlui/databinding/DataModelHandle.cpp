#include <databinding/DataModelHandle.h>
#include <databinding/DataModel.h>
#include <assert.h>

namespace Rml {

DataModelHandle::DataModelHandle(DataModel* model) : model(model)
{}

bool DataModelHandle::IsVariableDirty(const std::string& variable_name) {
	return model->IsVariableDirty(variable_name);
}

void DataModelHandle::DirtyVariable(const std::string& variable_name) {
	model->DirtyVariable(variable_name);
}

DataModelConstructor::DataModelConstructor() : model(nullptr) {}

DataModelConstructor::DataModelConstructor(DataModel* model) : model(model) {
	assert(model);
}

DataModelHandle DataModelConstructor::GetModelHandle() const {
	return DataModelHandle(model);
}

bool DataModelConstructor::BindEventCallback(const std::string& name, DataEventFunc event_func) {
	return model->BindEventCallback(name, std::move(event_func));
}

bool DataModelConstructor::BindVariable(const std::string& name, DataVariable data_variable) {
	return model->BindVariable(name, data_variable);
}

}
