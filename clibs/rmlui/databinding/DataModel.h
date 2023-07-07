#pragma once

namespace Rml {

class DataModel {
public:
	DataModel();
	~DataModel();

	DataModel(const DataModel&) = delete;
	DataModel& operator=(const DataModel&) = delete;

	void CleanDirty();
	void MarkDirty();
	bool IsDirty() const;
	void Update();

private:
	bool dirty = false;
};

}
