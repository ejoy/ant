#pragma once

#include "../Include/RmlUi/Types.h"
#include "../Include/RmlUi/Variant.h"
#include "DataExpression.h"
#include "HtmlParser.h"
#include "DataView.h"

namespace Rml {

class Element;
class DataExpression;
using DataExpressionPtr = std::unique_ptr<DataExpression>;

class DataViewStyle final : public DataView {
public:
	DataViewStyle(Element* element, const std::string& modifier);
	bool Initialize(DataModel& model, const std::string& expression);
	std::vector<std::string> GetVariableNameList() const override;
	bool Update(DataModel& model) override;
private:
	std::string modifier;
	DataExpressionPtr expression;
};

class DataViewIf final : public DataView {
public:
	DataViewIf(Element* element);
	bool Initialize(DataModel& model, const std::string& expression);
	std::vector<std::string> GetVariableNameList() const override;
	bool Update(DataModel& model) override;
private:
	DataExpressionPtr expression;
};

class DataViewFor final : public DataView {
public:
	DataViewFor(Element* element);
	bool Initialize(DataModel& model, const std::string& expression);
	bool Update(DataModel& model) override;
	std::vector<std::string> GetVariableNameList() const override;

private:
	DataAddress container_address;
	std::string iterator_name;
	std::string iterator_index_name;
	size_t num_elements = 0;
};

class DataViewText final : public DataView {
public:
	DataViewText(Element* element);
	bool Initialize(DataModel& model);
	bool Update(DataModel& model) override;
	std::vector<std::string> GetVariableNameList() const override;

private:
	std::string BuildText() const;
	struct DataEntry {
		size_t index = 0; // Index into 'text'
		DataExpressionPtr data_expression;
		std::string value;
	};
	std::string text;
	std::vector<DataEntry> data_entries;
};

}
