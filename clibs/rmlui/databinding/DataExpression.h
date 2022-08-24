#pragma once

#include <databinding/DataTypes.h>

namespace Rml {

/*
	The abstract machine for RmlUi data expressions.

	The machine can execute a program which contains a list of instructions listed below.

	The abstract machine has three registers:
		R  Typically results and right-hand side arguments.
		L  Typically left-hand side arguments.
		C  Typically center arguments (eg. in ternary operator).

	And two stacks:
		S  The main program stack.
		A  The arguments stack, only used to pass arguments to an external transform function.

	In addition, each instruction has an optional payload:
		D  Instruction data (payload).

	Notation used in the instruction list below:
		S+  Push to stack S.
		S-  Pop stack S (returns the popped value).
*/
enum class Instruction : uint8_t {
	                        // Assignment (register/stack) = Read (register R/L/C, instruction data D, or stack)
	Push         = 'P',     //      S+ = R
	Pop          = 'o',     // <R/L/C> = S-  (D determines R/L/C)
	Literal      = 'D',     //       R = D
	Variable     = 'V',     //       R = DataModel.GetVariable(D)  (D is an index into the variable address list)
	Add          = '+',     //       R = L + R
	Subtract     = '-',     //       R = L - R
	Multiply     = '*',     //       R = L * R
	Divide       = '/',     //       R = L / R
	Not          = '!',     //       R = !R
	And          = '&',     //       R = L && R
	Or           = '|',     //       R = L || R
	Less         = '<',     //       R = L < R
	LessEq       = 'L',     //       R = L <= R
	Greater      = '>',     //       R = L > R
	GreaterEq    = 'G',     //       R = L >= R
	Equal        = '=',     //       R = L == R
	NotEqual     = 'N',     //       R = L != R
	Ternary      = '?',     //       R = L ? C : R
	Arguments    = 'a',     //      A+ = S-  (Repeated D times, where D gives the num. arguments)
	EventFnc     = 'E',     //       DataModel.EventCallback(D, A); A.Clear();
	Assign       = 'A',     //       DataModel.SetVariable(D, R)
};

struct InstructionData {
	Instruction instruction;
	Variant data;
};

class Element;
class Node;
class DataModel;
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
