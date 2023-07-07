#pragma once

#include <databinding/DataVariant.h>
#include <databinding/DataTypes.h>
#include <core/ObserverPtr.h>
#include <memory>
#include <string>
#include <vector>

namespace Rml {

class DataModel;
class Node;
class Text;
class Element;

class DataView {
public:
	virtual ~DataView() {}
	virtual bool Update(DataModel& model) = 0;
	virtual std::vector<std::string> GetVariableNameList() const = 0;
	virtual bool IsValid() const = 0;
	int GetDepth() const;
	
protected:
	DataView(Node* node);
	int depth;
};

class DataViewFor final : public DataView {
public:
	DataViewFor(Element* element);
	bool Initialize(DataModel& model, const std::string& expression);
	bool Update(DataModel& model) override;
	std::vector<std::string> GetVariableNameList() const override;
	bool IsValid() const override;

private:
	ObserverPtr<Element> element;
	DataAddress container_address;
	std::string iterator_name;
	std::string iterator_index_name;
	size_t num_elements = 0;
};

}
