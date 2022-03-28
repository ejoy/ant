#pragma once

#include "../Include/RmlUi/Types.h"
#include "../Include/RmlUi/DataTypes.h"

namespace Rml {

class Element;
class DataModel;

class DataViewInstancer {
public:
	DataViewInstancer() {}
	virtual ~DataViewInstancer() {}
	virtual DataViewPtr InstanceView(Element* element) = 0;

	DataViewInstancer(const DataViewInstancer&) = delete;
	DataViewInstancer& operator=(const DataViewInstancer&) = delete;
};

template<typename T>
class DataViewInstancerDefault final : public DataViewInstancer {
public:
	DataViewPtr InstanceView(Element* element) override {
		return DataViewPtr(new T(element));
	}
};

class DataView {
public:
	virtual bool Initialize(DataModel& model, Element* element, const std::string& expression, const std::string& modifier_or_inner_html) = 0;
	virtual bool Update(DataModel& model) = 0;
	virtual std::vector<std::string> GetVariableNameList() const = 0;
	Element* GetElement() const;
	int GetElementDepth() const;
	bool IsValid() const;
	
protected:
	DataView(Element* element);

private:
	ObserverPtr<Element> attached_element;
	int element_depth;
};

}
