#pragma once

#include <databinding/DataTypes.h>

namespace Rml {

class Element;
class Node;
class DataModel;
struct InstructionData;
using Program = std::vector<InstructionData>;
using AddressList = std::vector<DataAddress>;

class DataExpressionInterface {
public:
    DataExpressionInterface() = default;
    DataExpressionInterface(DataModel* data_model, Node* element, Event* event = nullptr);
    DataAddress ParseAddress(const std::string& address_str) const;
    Variant GetValue(const DataAddress& address) const;
    bool SetValue(const DataAddress& address, const Variant& value) const;
    bool EventCallback(const std::string& name, const std::vector<Variant>& arguments);

private:
    DataModel* data_model = nullptr;
    Node* element = nullptr;
    Event* event = nullptr;
};

class DataExpression {
public:
    DataExpression();
    ~DataExpression();
    bool Parse(const DataExpressionInterface& expression_interface, const std::string& expression, bool is_assignment_expression);
    bool Run(const DataExpressionInterface& expression_interface, Variant& out_value);
    std::vector<std::string> GetVariableNameList() const;

private:
    Program program;
    AddressList addresses;
};

}
