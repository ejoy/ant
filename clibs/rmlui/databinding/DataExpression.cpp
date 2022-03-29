/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2008-2010 CodePoint Ltd, Shift Technology Ltd
 * Copyright (c) 2019 The RmlUi Team, and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#include "databinding/DataExpression.h"
#include "databinding/DataModelHandle.h"
#include "core/Variant.h"
#include "core/Log.h"
#include "core/StringUtilities.h"
#include "databinding/DataModel.h"
#include <stack>

#ifdef _MSC_VER
#pragma warning(default : 4061)
#pragma warning(default : 4062)
#endif

namespace Rml {

class DataParser;

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
enum class Instruction {    
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

enum class Register {
	R,
	L,
	C
};

struct InstructionData {
	Instruction instruction;
	Variant data;
};

namespace Parse {
	static void Assignment(DataParser& parser);
	static void Expression(DataParser& parser);
}


class DataParser {
public:
	DataParser(std::string expression, DataExpressionInterface expression_interface) : expression(std::move(expression)), expression_interface(expression_interface) {}

	char Look() {
		if (reached_end)
			return '\0';
		return expression[index];
	}

	bool Match(char c, bool skip_whitespace = true) {
		if (c == Look()) {
			Next();
			if (skip_whitespace)
				SkipWhitespace();
			return true;
		}
		Expected(c);
		return false;
	}

	char Next() {
		++index;
		if (index >= expression.size())
			reached_end = true;
		return Look();
	}

	void SkipWhitespace() {
		char c = Look();
		while (StringUtilities::IsWhitespace(c))
			c = Next();
	}

	void Error(const std::string message)
	{
		parse_error = true;
		Log::Message(Log::Level::Warning, "Error in data expression at %d. %s", index, message.c_str());
		Log::Message(Log::Level::Warning, "  \"%s\"", expression.c_str());
		
		const size_t cursor_offset = size_t(index) + 3;
		const std::string cursor_string = std::string(cursor_offset, ' ') + '^';
		Log::Message(Log::Level::Warning, cursor_string.c_str());
	}
	void Expected(std::string expected_symbols) {
		const char c = Look();
		if (c == '\0')
			Error(CreateString(expected_symbols.size() + 50, "Expected %s but found end of string.", expected_symbols.c_str()));
		else
			Error(CreateString(expected_symbols.size() + 50, "Expected %s but found character '%c'.", expected_symbols.c_str(), c));
	}
	void Expected(char expected) {
		Expected(std::string(1, '\'') + expected + '\'');
	}

	bool Parse(bool is_assignment_expression)
	{
		program.clear();
		variable_addresses.clear();
		index = 0;
		reached_end = false;
		parse_error = false;
		if (expression.empty())
			reached_end = true;

		SkipWhitespace();

		if (is_assignment_expression)
			Parse::Assignment(*this);
		else
			Parse::Expression(*this);
		
		if (!reached_end) {
			parse_error = true;
			Error(CreateString(50, "Unexpected character '%c' encountered.", Look()));
		}
		if (!parse_error && program_stack_size != 0) {
			parse_error = true;
			Error(CreateString(120, "Internal parser error, inconsistent stack operations. Stack size is %d at parse end.", program_stack_size));
		}

		return !parse_error;
	}

	Program ReleaseProgram() {
		assert(!parse_error);
		return std::move(program);
	}
	AddressList ReleaseAddresses() {
		assert(!parse_error);
		return std::move(variable_addresses);
	}

	void Emit(Instruction instruction, Variant data = Variant())
	{
		assert(instruction != Instruction::Push && instruction != Instruction::Pop &&
			instruction != Instruction::Arguments && instruction != Instruction::Variable && instruction != Instruction::Assign);
		program.push_back(InstructionData{ instruction, std::move(data) });
	}
	void Push() {
		program_stack_size += 1;
		program.push_back(InstructionData{ Instruction::Push, Variant() });
	}
	void Pop(Register destination) {
		if (program_stack_size <= 0) {
			Error("Internal parser error: Tried to pop an empty stack.");
			return;
		}
		program_stack_size -= 1;
		program.push_back(InstructionData{ Instruction::Pop, Variant(int(destination)) });
	}
	void Arguments(int num_arguments) {
		if (program_stack_size < num_arguments) {
			Error(CreateString(128, "Internal parser error: Popping %d arguments, but the stack contains only %d elements.", num_arguments, program_stack_size));
			return;
		}
		program_stack_size -= num_arguments;
		program.push_back(InstructionData{ Instruction::Arguments, Variant(int(num_arguments)) });
	}
	void Variable(const std::string& name) {
		VariableGetSet(name, false);
	}
	void Assign(const std::string& name) {
		VariableGetSet(name, true);
	}

private:
	void VariableGetSet(const std::string& name, bool is_assignment)
	{
		DataAddress address = expression_interface.ParseAddress(name);
		if (address.empty()) {
			Error(CreateString(name.size() + 50, "Could not find data variable with name '%s'.", name.c_str()));
			return;
		}
		int index = int(variable_addresses.size());
		variable_addresses.push_back(std::move(address));
		program.push_back(InstructionData{ is_assignment ? Instruction::Assign : Instruction::Variable, Variant(int(index)) });
	}

	const std::string expression;
	DataExpressionInterface expression_interface;

	size_t index = 0;
	bool reached_end = false;
	bool parse_error = true;
	int program_stack_size = 0;

	Program program;
	
	AddressList variable_addresses;
};


namespace Parse {

	// Forward declare all parse functions.
	static void Assignment(DataParser& parser);

	// The following in order of precedence.
	static void Expression(DataParser& parser);
	static void Relational(DataParser& parser);
	static void Additive(DataParser& parser);
	static void Term(DataParser& parser);
	static void Factor(DataParser& parser);

	static void NumberLiteral(DataParser& parser);
	static void StringLiteral(DataParser& parser);
	static void Variable(DataParser& parser);

	static void Add(DataParser& parser);
	static void Subtract(DataParser& parser);
	static void Multiply(DataParser& parser);
	static void Divide(DataParser& parser);

	static void Not(DataParser& parser);
	static void And(DataParser& parser);
	static void Or(DataParser& parser);
	static void Less(DataParser& parser);
	static void Greater(DataParser& parser);
	static void Equal(DataParser& parser);
	static void NotEqual(DataParser& parser);

	static void Ternary(DataParser& parser);
	static void Function(DataParser& parser, Instruction function_type, const std::string& name);

	// Helper functions
	static bool IsVariableCharacter(char c, bool is_first_character)
	{
		const bool is_alpha = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');

		if (is_first_character)
			return is_alpha;

		if (is_alpha || (c >= '0' && c <= '9'))
			return true;

		for (char valid_char : "_.[] ")
		{
			if (c == valid_char && valid_char != '\0')
				return true;
		}

		return false;
	}
	static std::string VariableName(DataParser& parser)
	{
		std::string name;

		bool is_first_character = true;
		char c = parser.Look();

		while (IsVariableCharacter(c, is_first_character))
		{
			name += c;
			c = parser.Next();
			is_first_character = false;
		}

		// Right trim spaces in name
		size_t new_size = std::string::npos;
		for (int i = int(name.size()) - 1; i >= 1; i--)
		{
			if (name[i] == ' ')
				new_size = size_t(i);
			else
				break;
		}
		if (new_size != std::string::npos)
			name.resize(new_size);

		return name;
	}

	// Parser functions
	static void Assignment(DataParser& parser)
	{
		bool looping = true;
		while (looping)
		{
			if (parser.Look() != '\0')
			{
				const std::string variable_name = VariableName(parser);
				if (variable_name.empty()) {
					parser.Error("Expected a variable for assignment but got an empty name.");
					return;
				}

				const char c = parser.Look();
				if (c == '=')
				{
					parser.Match('=');
					Expression(parser);
					parser.Assign(variable_name);
				}
				else if (c == '(' || c == ';' || c == '\0')
				{
					Function(parser, Instruction::EventFnc, variable_name);
				}
				else
				{
					parser.Expected("one of  = ; (  or end of string");
					return;
				}
			}

			const char c = parser.Look();
			if (c == ';')
				parser.Match(';');
			else if (c == '\0')
				looping = false;
			else
			{
				parser.Expected("';' or end of string");
				looping = false;
			}
		}
	}
	static void Expression(DataParser& parser)
	{
		Relational(parser);

		bool looping = true;
		while (looping)
		{
			switch (parser.Look())
			{
			case '&': And(parser); break;
			case '|': Or(parser); break;
			case '?': Ternary(parser); break;
			default:
				looping = false;
			}
		}
	}

	static void Relational(DataParser& parser)
	{
		Additive(parser);

		bool looping = true;
		while (looping)
		{
			switch (parser.Look())
			{
			case '=': Equal(parser); break;
			case '!': NotEqual(parser); break;
			case '<': Less(parser); break;
			case '>': Greater(parser); break;
			default:
				looping = false;
			}
		}
	}
	
	static void Additive(DataParser& parser)
	{
		Term(parser);

		bool looping = true;
		while (looping)
		{
			switch (parser.Look())
			{
			case '+': Add(parser); break;
			case '-': Subtract(parser); break;
			default:
				looping = false;
			}
		}
	}


	static void Term(DataParser& parser)
	{
		Factor(parser);

		bool looping = true;
		while (looping)
		{
			switch (parser.Look())
			{
			case '*': Multiply(parser); break;
			case '/': Divide(parser); break;
			default:
				looping = false;
			}
		}
	}
	static void Factor(DataParser& parser)
	{
		const char c = parser.Look();

		if (c == '(')
		{
			parser.Match('(');
			Expression(parser);
			parser.Match(')');
		}
		else if (c == '\'')
		{
			parser.Match('\'', false);
			StringLiteral(parser);
			parser.Match('\'');
		}
		else if (c == '!')
		{
			Not(parser);
			parser.SkipWhitespace();
		}
		else if (c == '-' || (c >= '0' && c <= '9'))
		{
			NumberLiteral(parser);
			parser.SkipWhitespace();
		}
		else if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'))
		{
			Variable(parser);
			parser.SkipWhitespace();
		}
		else
			parser.Expected("literal, variable name, parenthesis, or '!'");
	}

	static void NumberLiteral(DataParser& parser)
	{
		std::string str;

		bool first_match = false;
		bool has_dot = false;
		char c = parser.Look();
		if (c == '-')
		{
			str += c;
			c = parser.Next();
		}

		while ((c >= '0' && c <= '9') || (c == '.' && !has_dot))
		{
			first_match = true;
			str += c;
			if (c == '.')
				has_dot = true;
			c = parser.Next();
		}

		if (!first_match)
		{
			parser.Error(CreateString(100, "Invalid number literal. Expected '0-9' or '.' but found '%c'.", c));
			return;
		}

		const float number = FromString(str, 0.0f);

		parser.Emit(Instruction::Literal, Variant(number));
	}
	static void StringLiteral(DataParser& parser)
	{
		std::string str;

		char c = parser.Look();
		char c_prev = '\0';

		while (c != '\0' && (c != '\'' || c_prev == '\\'))
		{
			if (c_prev == '\\' && (c == '\\' || c == '\'')) {
				str.pop_back();
				c_prev = '\0';
			}
			else {
				c_prev = c;
			}

			str += c;
			c = parser.Next();
		}

		parser.Emit(Instruction::Literal, Variant(str));
	}
	static void Variable(DataParser& parser)
	{
		std::string name = VariableName(parser);
		if (name.empty()) {
			parser.Error("Expected a variable but got an empty name.");
			return;
		}

		// Keywords are parsed like variables, but are really literals.
		// Check for them here.
		if (name == "true")
			parser.Emit(Instruction::Literal, Variant(true));
		else if (name == "false")
			parser.Emit(Instruction::Literal, Variant(false));
		else
			parser.Variable(name);
	}

	static void Add(DataParser& parser)
	{
		parser.Match('+');
		parser.Push();
		Term(parser);
		parser.Pop(Register::L);
		parser.Emit(Instruction::Add);
	}
	static void Subtract(DataParser& parser)
	{
		parser.Match('-');
		parser.Push();
		Term(parser);
		parser.Pop(Register::L);
		parser.Emit(Instruction::Subtract);
	}
	static void Multiply(DataParser& parser)
	{
		parser.Match('*');
		parser.Push();
		Factor(parser);
		parser.Pop(Register::L);
		parser.Emit(Instruction::Multiply);
	}
	static void Divide(DataParser& parser)
	{
		parser.Match('/');
		parser.Push();
		Factor(parser);
		parser.Pop(Register::L);
		parser.Emit(Instruction::Divide);
	}

	static void Not(DataParser& parser)
	{
		parser.Match('!');
		Factor(parser);
		parser.Emit(Instruction::Not);
	}
	static void Or(DataParser& parser)
	{
		parser.Match('|', false);
		parser.Match('|');
		parser.Push();
		Relational(parser);
		parser.Pop(Register::L);
		parser.Emit(Instruction::Or);
	}
	static void And(DataParser& parser)
	{
		parser.Match('&', false);
		parser.Match('&');
		parser.Push();
		Relational(parser);
		parser.Pop(Register::L);
		parser.Emit(Instruction::And);
	}
	static void Less(DataParser& parser)
	{
		Instruction instruction = Instruction::Less;
		parser.Match('<', false);
		if (parser.Look() == '=') {
			parser.Match('=');
			instruction = Instruction::LessEq;
		}
		else {
			parser.SkipWhitespace();
		}
		parser.Push();
		Additive(parser);
		parser.Pop(Register::L);
		parser.Emit(instruction);
	}
	static void Greater(DataParser& parser)
	{
		Instruction instruction = Instruction::Greater;
		parser.Match('>', false);
		if (parser.Look() == '=') {
			parser.Match('=');
			instruction = Instruction::GreaterEq;
		}
		else {
			parser.SkipWhitespace();
		}
		parser.Push();
		Additive(parser);
		parser.Pop(Register::L);
		parser.Emit(instruction);
	}
	static void Equal(DataParser& parser)
	{
		parser.Match('=', false);
		parser.Match('=');
		parser.Push();
		Additive(parser);
		parser.Pop(Register::L);
		parser.Emit(Instruction::Equal);
	}
	static void NotEqual(DataParser& parser)
	{
		parser.Match('!', false);
		parser.Match('=');
		parser.Push();
		Additive(parser);
		parser.Pop(Register::L);
		parser.Emit(Instruction::NotEqual);
	}

	static void Ternary(DataParser& parser)
	{
		parser.Match('?');
		parser.Push();
		Expression(parser);
		parser.Push();
		parser.Match(':');
		Expression(parser);
		parser.Pop(Register::C);
		parser.Pop(Register::L);
		parser.Emit(Instruction::Ternary);
	}
	static void Function(DataParser& parser, Instruction function_type, const std::string& func_name)
	{
		assert(function_type == Instruction::EventFnc);

		// We already matched the variable name (and '|' for transform functions)
		if (parser.Look() == '(')
		{
			int num_arguments = 0;
			bool looping = true;

			parser.Match('(');
			if (parser.Look() == ')') {
				parser.Match(')');
				looping = false;
			}
			else
				parser.Push();

			while (looping)
			{
				num_arguments += 1;
				Expression(parser);
				parser.Push();

				switch (parser.Look()) {
				case ')': parser.Match(')'); looping = false; break;
				case ',': parser.Match(','); break;
				default:
					parser.Expected("one of ')' or ','");
					looping = false;
				}
			}

			if (num_arguments > 0) {
				parser.Arguments(num_arguments);
				parser.Pop(Register::R);
			}
		}
		else {
			parser.SkipWhitespace();
		}

		parser.Emit(function_type, Variant(func_name));
	}


} // </namespace Parse>



class DataInterpreter {
public:
	DataInterpreter(const Program& program, const AddressList& addresses, DataExpressionInterface expression_interface)
		: program(program), addresses(addresses), expression_interface(expression_interface) {}

	bool Error(std::string message) const
	{
		Log::Message(Log::Level::Error, "Error during execution. %s", message.c_str());
		return false;
	}

	bool Run()
	{
		bool success = true;
		for (size_t i = 0; i < program.size(); i++)
		{
			if (!Execute(program[i].instruction, program[i].data))
			{
				success = false;
				break;
			}
		}

		if(success && !stack.empty())
			Log::Message(Log::Level::Warning, "Possible data interpreter stack corruption. Stack size is %d at end of execution (should be zero).", stack.size());

		if(!success)
		{
			std::string program_str = DumpProgram();
			Log::Message(Log::Level::Warning, "Failed to execute program with %d instructions:", program.size());
			Log::Message(Log::Level::Warning, program_str.c_str());
		}

		return success;
	}

	std::string DumpProgram() const
	{
		std::string str;
		for (size_t i = 0; i < program.size(); i++)
		{
			std::string instruction_str = VariantHelper::Get<std::string>(program[i].data);
			str += CreateString(50 + instruction_str.size(), "  %4zu  '%c'  %s\n", i, char(program[i].instruction), instruction_str.c_str());
		}
		return str;
	}

	Variant Result() const {
		return R;
	}


private:
	Variant R, L, C;
	std::stack<Variant> stack;
	std::vector<Variant> arguments;

	const Program& program;
	const AddressList& addresses;
	DataExpressionInterface expression_interface;

	bool Execute(const Instruction instruction, const Variant& data)
	{
		auto AnyString = [](const Variant& v1, const Variant& v2) {
			return std::holds_alternative<std::string>(v1) || std::holds_alternative<std::string>(v2);
		};

		auto Compute = [](const Instruction op, const Variant& l, const Variant& r) {
			auto lv = (VariantHelper::Has<float>(l) ? VariantHelper::Get<float>(l) : VariantHelper::Get<int>(l));
			auto rv = (VariantHelper::Has<float>(r) ? VariantHelper::Get<float>(r) : VariantHelper::Get<int>(r));
			float value = 0.0f;
			switch (op) {
			case Instruction::Add: value = lv + rv; break;
			case Instruction::Subtract: value = lv - rv; break;
			case Instruction::Multiply: value = lv * rv; break;
			default: break;
			}
			if (VariantHelper::Has<int>(l) && VariantHelper::Has<int>(r)) {
				return Variant((int)value);
			} else {
				return Variant(value);
			}
		};

		switch (instruction)
		{
		case Instruction::Push:
		{
			stack.push(std::move(R));
			R = Variant {};
		}
		break;
		case Instruction::Pop:
		{
			if (stack.empty())
				return Error("Cannot pop stack, it is empty.");

			Register reg = Register(VariantHelper::Get<int>(data, -1));
			switch (reg) {
			case Register::R:  R = stack.top(); stack.pop(); break;
			case Register::L:  L = stack.top(); stack.pop(); break;
			case Register::C:  C = stack.top(); stack.pop(); break;
			default:
				return Error(CreateString(50, "Invalid register %d.", int(reg)));
			}
		}
		break;
		case Instruction::Literal:
		{
			R = data;
		}
		break;
		case Instruction::Variable:
		{
			size_t variable_index = size_t(VariantHelper::Get<int>(data, -1));
			if (variable_index < addresses.size())
				R = expression_interface.GetValue(addresses[variable_index]);
			else
				return Error("Variable address not found.");
		}
		break;
		case Instruction::Add:
		{
			if (AnyString(L, R))
				R = Variant(VariantHelper::ToString(L) + VariantHelper::ToString(R));
			else {
				//R = Variant(VariantHelper::Get<float>(L) + VariantHelper::Get<float>(R));
				R = Compute(instruction, L, R);
			}
		}
		break;
		case Instruction::Subtract:  R = Compute(instruction, L, R); break;
		case Instruction::Multiply:  R = Compute(instruction, L, R); break;
		case Instruction::Divide:    R = Variant(VariantHelper::Get<float>(L) / VariantHelper::Get<float>(R));  break;
		case Instruction::Not:       R = Variant(!VariantHelper::Get<bool>(R));                     break;
		case Instruction::And:       R = Variant(VariantHelper::Get<bool>(L) && VariantHelper::Get<bool>(R));     break;
		case Instruction::Or:        R = Variant(VariantHelper::Get<bool>(L) || VariantHelper::Get<bool>(R));     break;
		case Instruction::Less:      R = Variant(VariantHelper::ConvertGet<float>(L) < VariantHelper::ConvertGet<float>(R));  break;
		case Instruction::LessEq:    R = Variant(VariantHelper::ConvertGet<float>(L) <= VariantHelper::ConvertGet<float>(R)); break;
		case Instruction::Greater:   R = Variant(VariantHelper::ConvertGet<float>(L) > VariantHelper::ConvertGet<float>(R));  break;
		case Instruction::GreaterEq: R = Variant(VariantHelper::ConvertGet<float>(L) >= VariantHelper::ConvertGet<float>(R)); break;
		case Instruction::Equal:
		{
			if (AnyString(L, R))
				R = Variant(VariantHelper::Get<std::string>(L) == VariantHelper::Get<std::string>(R));
			else
				R = Variant(VariantHelper::ConvertGet<float>(L) == VariantHelper::ConvertGet<float>(R));
		}
		break;
		case Instruction::NotEqual:
		{
			if (AnyString(L, R))
				R = Variant(VariantHelper::Get<std::string>(L) != VariantHelper::Get<std::string>(R));
			else
				R = Variant(VariantHelper::Get<float>(L) != VariantHelper::Get<float>(R));
		}
		break;
		case Instruction::Ternary:
		{
			if (VariantHelper::Get<bool>(L))
				R = C;
		}
		break;
		case Instruction::Arguments:
		{
			if (!arguments.empty())
				return Error("Argument stack is not empty.");

			int num_arguments = VariantHelper::Get<int>(data, -1);
			if (num_arguments < 0)
				return Error("Invalid number of arguments.");
			if (stack.size() < size_t(num_arguments))
				return Error(CreateString(100, "Cannot pop %d arguments, stack contains only %zu elements.", num_arguments, stack.size()));

			arguments.resize(num_arguments);
			for (int i = num_arguments - 1; i >= 0; i--)
			{
				arguments[i] = std::move(stack.top());
				stack.pop();
			}
		}
		break;
		case Instruction::EventFnc:
		{
			const std::string function_name = VariantHelper::Get<std::string>(data);

			if (!expression_interface.EventCallback(function_name, arguments))
			{
				std::string arguments_str;
				for (size_t i = 0; i < arguments.size(); i++)
				{
					arguments_str += VariantHelper::Get<std::string>(arguments[i]);
					if (i < arguments.size() - 1)
						arguments_str += ", ";
				}
				Error(CreateString(50 + function_name.size() + arguments_str.size(), "Failed to execute event callback: %s(%s)", function_name.c_str(), arguments_str.c_str()));
			}

			arguments.clear();
		}
		break;
		case Instruction::Assign:
		{
			size_t variable_index = size_t(VariantHelper::Get<int>(data, -1));
			if (variable_index < addresses.size())
			{
				if (!expression_interface.SetValue(addresses[variable_index], R))
					return Error("Could not assign to variable.");
			}
			else
				return Error("Variable address not found.");
		}
		break;
		default:
			Log::Message(Log::Level::Error, "Instruction not implemented."); break;
		}
		return true;
	}
};


DataExpression::DataExpression(std::string expression) : expression(expression)
{}

DataExpression::~DataExpression()
{}

bool DataExpression::Parse(const DataExpressionInterface& expression_interface, bool is_assignment_expression) {
	DataParser parser(expression, expression_interface);
	if (!parser.Parse(is_assignment_expression))
		return false;

	program = parser.ReleaseProgram();
	addresses = parser.ReleaseAddresses();

	return true;
}

bool DataExpression::Run(const DataExpressionInterface& expression_interface, Variant& out_value) {
	DataInterpreter interpreter(program, addresses, expression_interface);
	
	if (!interpreter.Run())
		return false;

	out_value = interpreter.Result();
	return true;
}

std::vector<std::string> DataExpression::GetVariableNameList() const {
	std::vector<std::string> list;
	list.reserve(addresses.size());
	for (const DataAddress& address : addresses) {
		if (!address.empty())
			list.push_back(address[0].name);
	}
	return list;
}

DataExpressionInterface::DataExpressionInterface(DataModel* data_model, Node* element, Event* event)
	: data_model(data_model)
	, element(element)
	, event(event)
{}

DataAddress DataExpressionInterface::ParseAddress(const std::string& address_str) const {
	return data_model ? data_model->ResolveAddress(address_str, element) : DataAddress();
}

Variant DataExpressionInterface::GetValue(const DataAddress& address) const {
	Variant result;
	if (data_model) {
		data_model->GetVariableInto(address, result);
	}
	return result;
}

bool DataExpressionInterface::SetValue(const DataAddress& address, const Variant& value) const {
	bool result = false;
	if (data_model && !address.empty()) {
		if (DataVariable variable = data_model->GetVariable(address))
			result = variable.Set(value);

		if (result)
			data_model->DirtyVariable(address.front().name);
	}
	return result;
}

bool DataExpressionInterface::EventCallback(const std::string& name, const std::vector<Variant>& arguments) {
	if (!data_model || !event)
		return false;

	const DataEventFunc* func = data_model->GetEventCallback(name);
	if (!func || !*func)
		return false;

	DataModelHandle handle(data_model);
	func->operator()(handle, *event, arguments);
	return true;
}

}
