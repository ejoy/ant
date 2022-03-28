#pragma once

#include "../Include/RmlUi/Types.h"
#include "../Include/RmlUi/DataTypes.h"

namespace Rml {

class Element;
class DataModel;

class DataView {
public:
	virtual bool Update(DataModel& model) = 0;
	virtual std::vector<std::string> GetVariableNameList() const = 0;
	Element* GetElement() const;
	int GetDepth() const;
	bool IsValid() const;
	
protected:
	DataView(Element* element);

	ObserverPtr<Element> element;
	int depth;
};

}
