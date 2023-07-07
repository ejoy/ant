#include <databinding/DataModel.h>

namespace Rml {

DataModel::DataModel()
{}

DataModel::~DataModel() {
}

void DataModel::CleanDirty() {
	dirty = false;
}

void DataModel::MarkDirty() {
	dirty = true;
}

bool DataModel::IsDirty() const {
	return dirty;
}

}
