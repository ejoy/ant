#pragma once

#include <string>
#include <vector>

namespace Rml {

class Element;
class DataModel;

class DataView {
public:
	virtual bool Update(DataModel& model) = 0;
	virtual std::vector<std::string> GetVariableNameList() const = 0;
	virtual bool IsValid() const = 0;
	int GetDepth() const;
	
protected:
	DataView(Element* element);
	int depth;
};

}
