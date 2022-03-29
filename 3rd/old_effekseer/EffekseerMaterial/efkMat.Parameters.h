
#pragma once

#include "efkMat.Base.h"
#include "efkMat.Models.h"

namespace EffekseerMaterial
{

ValueType InferOutputTypeIn1Out1(const std::vector<ValueType>& inputTypes);

ValueType InferOutputTypeIn2Out1Param2(const std::vector<ValueType>& inputTypes);

ValueType InferOutputTypeInAppendVector(const std::vector<ValueType>& inputTypes);

struct ExtractedTextureParameter
{
	//! parameter GUID
	uint64_t GUID = 0;

	//! fixed path
	std::string Path;

	//! sampler
	TextureSamplerType Sampler;
};

//! extract output texture or sampled texture
bool ExtractTextureParameter(std::shared_ptr<Material> material, std::shared_ptr<Node> node, ExtractedTextureParameter& result);

enum class ShadingModelType
{
	Lit,
	Unlit,
};

class PinParameter
{
public:
	std::string Name;
	std::string Description;
	ValueType Type;
	DefaultType Default;
	std::array<float, 4> DefaultValues;

	PinParameter() { DefaultValues.fill(0.0f); }
};

class NodePropertyParameter
{
public:
	std::string Name;
	std::string Description;
	ValueType Type;
	std::array<float, 4> DefaultValues;
	std::string DefaultStr;

	NodePropertyParameter() { DefaultValues.fill(0.0f); }
};

class NodeFunctionParameter
{
public:
	std::string Name;
	std::string Description;
	std::function<bool(std::shared_ptr<Material>, std::shared_ptr<Node>)> Func;
};

class NodeParameterBehaviorComponent
{
public:
	bool IsGetIsInputPinEnabledInherited = false;
	bool IsGetHeaderInherited = false;
	bool IsGetWarningInherited = false;

	virtual bool GetIsInputPinEnabled(std::shared_ptr<Material> material,
									  std::shared_ptr<NodeParameter> parameter,
									  std::shared_ptr<Node> node,
									  std::shared_ptr<Pin> pin)
	{
		return true;
	}

	virtual std::string
	GetHeader(std::shared_ptr<Material> material, std::shared_ptr<NodeParameter> parameter, std::shared_ptr<Node> node) const
	{
		return "";
	}

	virtual WarningType GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const { return WarningType::None; }
};

class NodeParameterBehaviorComponentTwoInputMath : public NodeParameterBehaviorComponent
{
public:
	NodeParameterBehaviorComponentTwoInputMath() { IsGetHeaderInherited = true; }

	std::string
	GetHeader(std::shared_ptr<Material> material, std::shared_ptr<NodeParameter> parameter, std::shared_ptr<Node> node) const override;
};

class NodeParameterBehaviorComponentMask : public NodeParameterBehaviorComponent
{
public:
	NodeParameterBehaviorComponentMask() { IsGetHeaderInherited = true; }

	std::string
	GetHeader(std::shared_ptr<Material> material, std::shared_ptr<NodeParameter> parameter, std::shared_ptr<Node> node) const override;
};

class NodeParameterBehaviorComponentParameter : public NodeParameterBehaviorComponent
{
public:
	NodeParameterBehaviorComponentParameter() {
		IsGetHeaderInherited = true; 
		IsGetWarningInherited = true;
	}

	std::string
	GetHeader(std::shared_ptr<Material> material, std::shared_ptr<NodeParameter> parameter, std::shared_ptr<Node> node) const override;

	WarningType GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const override;
};

class NodeParameterBehaviorConstantName : public NodeParameterBehaviorComponent
{
private:
	int32_t componentCount_ = 0;

public:
	NodeParameterBehaviorConstantName(int32_t componentCount) : componentCount_(componentCount) { IsGetHeaderInherited = true; }

	std::string
	GetHeader(std::shared_ptr<Material> material, std::shared_ptr<NodeParameter> parameter, std::shared_ptr<Node> node) const override;
};

class NodeParameterBehaviorComponentOutput : public NodeParameterBehaviorComponent
{
public:
	NodeParameterBehaviorComponentOutput() { IsGetIsInputPinEnabledInherited = true; }

	bool GetIsInputPinEnabled(std::shared_ptr<Material> material,
							  std::shared_ptr<NodeParameter> parameter,
							  std::shared_ptr<Node> node,
							  std::shared_ptr<Pin> pin) override;
};

class NodeParameter
{
protected:
	//! input 1, output 1, input type and output type are same
	ValueType GetOutputTypeIn1Out1(const std::vector<ValueType>& inputTypes) const;

	/*!
	@note
		input 2, output 1, parameter 2.
		parameter types are float1
		input type and output type are floatN and float1.
		input type and output type are float1 and floatN.
		input type and output type are same.
	*/
	ValueType GetOutputTypeIn2Out1Param2(const std::vector<ValueType>& inputTypes) const;

	/*!
	@note
	input 2, output 1, parameter 2.
	parameter types are float1
	input type and output type are floatN and float1.
	input type and output type are float1 and floatN.
	input type and output type are same.
	*/
	WarningType GetWarningIn2Out1Param2(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const;

	//! get warning about a sampler
	WarningType GetWarningSampler(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const;

	void InitializeAstOutputTypeIn1Out1()
	{
		auto input = std::make_shared<PinParameter>();
		input->Name = "Value";
		input->Type = ValueType::FloatN;
		InputPins.push_back(input);

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::FloatN;
		OutputPins.push_back(output);
	}

	void InitializeAsIn2Out1Param2()
	{
		auto input1 = std::make_shared<PinParameter>();
		input1->Name = "Value1";
		input1->Type = ValueType::FloatN;
		InputPins.push_back(input1);

		auto input2 = std::make_shared<PinParameter>();
		input2->Name = "Value2";
		input2->Type = ValueType::FloatN;
		InputPins.push_back(input2);

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::FloatN;
		OutputPins.push_back(output);

		auto val1 = std::make_shared<NodePropertyParameter>();
		val1->Name = "ConstValue1";
		val1->Type = ValueType::Float1;
		Properties.push_back(val1);

		auto val2 = std::make_shared<NodePropertyParameter>();
		val2->Name = "ConstValue2";
		val2->Type = ValueType::Float1;
		Properties.push_back(val2);
	}

public:
	NodeParameter() = default;
	virtual ~NodeParameter() = default;

	std::vector<std::shared_ptr<NodeParameterBehaviorComponent>> BehaviorComponents;

	NodeType Type;
	std::string TypeName;
	std::string Description;
	std::vector<std::string> Group;
	std::vector<std::string> Keywords;

	std::vector<std::shared_ptr<PinParameter>> InputPins;
	std::vector<std::shared_ptr<PinParameter>> OutputPins;

	std::vector<std::shared_ptr<NodePropertyParameter>> Properties;
	std::vector<std::shared_ptr<NodeFunctionParameter>> Funcs;

	//! is preview opened as default
	bool IsPreviewOpened = false;

	//! has a description for other editor
	bool HasDescription = false;

	//! is a description exported to json
	bool IsDescriptionExported = false;

	int32_t GetPropertyIndex(const std::string& name)
	{
		for (size_t i = 0; i < Properties.size(); i++)
		{
			if (Properties[i]->Name == name)
			{
				return static_cast<int32_t>(i);
			}
		}
		return -1;
	}

	virtual ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const
	{
		return ValueType::Unknown;
	}

	virtual std::string GetHeader(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const;

	virtual WarningType GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const { return WarningType::None; }
};

class NodeConstant1 : public NodeParameter
{
public:
	NodeConstant1();
};

class NodeConstant2 : public NodeParameter
{
public:
	NodeConstant2();
};

class NodeConstant3 : public NodeParameter
{
public:
	NodeConstant3();
};

class NodeConstant4 : public NodeParameter
{
public:
	NodeConstant4();
};

class NodeParameter1 : public NodeParameter
{
public:
	NodeParameter1()
	{
		Type = NodeType::Parameter1;
		TypeName = "Parameter1";
		Description = "Param value...";
		Group = std::vector<std::string>{"Parameter"};
		HasDescription = true;
		IsDescriptionExported = true;

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float1;
		OutputPins.push_back(output);

		auto paramName = std::make_shared<NodePropertyParameter>();
		paramName->Name = "Name";
		paramName->Type = ValueType::String;
		paramName->DefaultStr = "Noname";
		Properties.push_back(paramName);

		auto paramPriority = std::make_shared<NodePropertyParameter>();
		paramPriority->Name = "Priority";
		paramPriority->Type = ValueType::Int;
		paramPriority->DefaultValues[0] = 1;
		Properties.push_back(paramPriority);

		auto param = std::make_shared<NodePropertyParameter>();
		param->Name = "Value";
		param->Type = ValueType::Float1;
		Properties.push_back(param);

		BehaviorComponents = {std::make_shared<NodeParameterBehaviorComponentParameter>()};
	}
};

class NodeParameter2 : public NodeParameter
{
public:
	NodeParameter2()
	{
		Type = NodeType::Parameter2;
		TypeName = "Parameter2";
		Description = "Param value...";
		Group = std::vector<std::string>{"Parameter"};
		HasDescription = true;
		IsDescriptionExported = true;

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float2;
		OutputPins.push_back(output);

		auto paramName = std::make_shared<NodePropertyParameter>();
		paramName->Name = "Name";
		paramName->Type = ValueType::String;
		paramName->DefaultStr = "Noname";
		Properties.push_back(paramName);

		auto paramPriority = std::make_shared<NodePropertyParameter>();
		paramPriority->Name = "Priority";
		paramPriority->Type = ValueType::Int;
		paramPriority->DefaultValues[0] = 1;
		Properties.push_back(paramPriority);

		auto param = std::make_shared<NodePropertyParameter>();
		param->Name = "Value";
		param->Type = ValueType::Float2;
		Properties.push_back(param);

		BehaviorComponents = {std::make_shared<NodeParameterBehaviorComponentParameter>()};
	}
};

class NodeParameter3 : public NodeParameter
{
public:
	NodeParameter3()
	{
		Type = NodeType::Parameter3;
		TypeName = "Parameter3";
		Description = "Param value...";
		Group = std::vector<std::string>{"Parameter"};
		HasDescription = true;
		IsDescriptionExported = true;

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float3;
		OutputPins.push_back(output);

		auto paramName = std::make_shared<NodePropertyParameter>();
		paramName->Name = "Name";
		paramName->Type = ValueType::String;
		paramName->DefaultStr = "Noname";
		Properties.push_back(paramName);

		auto paramPriority = std::make_shared<NodePropertyParameter>();
		paramPriority->Name = "Priority";
		paramPriority->Type = ValueType::Int;
		paramPriority->DefaultValues[0] = 1;
		Properties.push_back(paramPriority);

		auto param = std::make_shared<NodePropertyParameter>();
		param->Name = "Value";
		param->Type = ValueType::Float3;
		Properties.push_back(param);

		BehaviorComponents = {std::make_shared<NodeParameterBehaviorComponentParameter>()};
	}
};

class NodeParameter4 : public NodeParameter
{
public:
	NodeParameter4()
	{
		Type = NodeType::Parameter4;
		TypeName = "Parameter4";
		Description = "Param value...";
		Group = std::vector<std::string>{"Parameter"};
		HasDescription = true;
		IsDescriptionExported = true;

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float4;
		OutputPins.push_back(output);

		auto paramName = std::make_shared<NodePropertyParameter>();
		paramName->Name = "Name";
		paramName->Type = ValueType::String;
		Properties.push_back(paramName);
		paramName->DefaultStr = "Noname";

		auto paramPriority = std::make_shared<NodePropertyParameter>();
		paramPriority->Name = "Priority";
		paramPriority->Type = ValueType::Int;
		paramPriority->DefaultValues[0] = 1;
		Properties.push_back(paramPriority);

		auto param = std::make_shared<NodePropertyParameter>();
		param->Name = "Value";
		param->Type = ValueType::Float4;
		Properties.push_back(param);

		BehaviorComponents = {std::make_shared<NodeParameterBehaviorComponentParameter>()};
	}
};

class NodeAbs : public NodeParameter
{
public:
	NodeAbs()
	{
		Type = NodeType::Abs;
		TypeName = "Abs";
		Group = std::vector<std::string>{"Math"};

		InitializeAstOutputTypeIn1Out1();
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return GetOutputTypeIn1Out1(inputTypes);
	}
};

class NodeOneMinus : public NodeParameter
{
public:
	NodeOneMinus()
	{
		Type = NodeType::OneMinus;
		TypeName = "OneMinus";
		Group = std::vector<std::string>{"Math"};

		InitializeAstOutputTypeIn1Out1();
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return GetOutputTypeIn1Out1(inputTypes);
	}
};

class NodeSine : public NodeParameter
{
public:
	NodeSine()
	{
		Type = NodeType::Sine;
		TypeName = "Sine";
		Group = std::vector<std::string>{"Math"};

		InitializeAstOutputTypeIn1Out1();
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return GetOutputTypeIn1Out1(inputTypes);
	}
};

class NodeArctangent2 : public NodeParameter
{
public:
	NodeArctangent2()
	{
		Type = NodeType::Arctangent2;
		TypeName = "Arctangent2";
		Group = std::vector<std::string>{"Math"};

		InitializeAsIn2Out1Param2();

		InputPins[0]->Name = "Y";
		InputPins[1]->Name = "X";
		Properties[0]->Name = "Y";
		Properties[1]->Name = "X";
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return GetOutputTypeIn2Out1Param2(inputTypes);
	}
	WarningType GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const override
	{
		return GetWarningIn2Out1Param2(material, node);
	}
};

class NodeComponentMask : public NodeParameter
{
public:
	NodeComponentMask()
	{
		Type = NodeType::ComponentMask;
		TypeName = "ComponentMask";
		Group = std::vector<std::string>{"Math"};

		auto input = std::make_shared<PinParameter>();
		input->Name = "Value";
		input->Type = ValueType::FloatN;
		InputPins.push_back(input);

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::FloatN;
		OutputPins.push_back(output);

		auto val1 = std::make_shared<NodePropertyParameter>();
		val1->Name = "R";
		val1->Type = ValueType::Bool;
		val1->DefaultValues[0] = 1.0f;
		Properties.push_back(val1);

		auto val2 = std::make_shared<NodePropertyParameter>();
		val2->Name = "G";
		val2->Type = ValueType::Bool;
		val2->DefaultValues[0] = 1.0f;
		Properties.push_back(val2);

		auto val3 = std::make_shared<NodePropertyParameter>();
		val3->Name = "B";
		val3->Type = ValueType::Bool;
		Properties.push_back(val3);

		auto val4 = std::make_shared<NodePropertyParameter>();
		val4->Name = "A";
		val4->Type = ValueType::Bool;
		Properties.push_back(val4);

		BehaviorComponents = {std::make_shared<NodeParameterBehaviorComponentMask>()};
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override;
	WarningType GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const override;
};

class NodeAppendVector : public NodeParameter
{
public:
	NodeAppendVector()
	{
		Type = NodeType::AppendVector;
		TypeName = "AppendVector";
		Group = std::vector<std::string>{"Math"};

		auto input1 = std::make_shared<PinParameter>();
		input1->Name = "Value1";
		input1->Type = ValueType::FloatN;
		InputPins.push_back(input1);

		auto input2 = std::make_shared<PinParameter>();
		input2->Name = "Value2";
		input2->Type = ValueType::FloatN;
		InputPins.push_back(input2);

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::FloatN;
		OutputPins.push_back(output);
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override;
	WarningType GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const override;
};

class NodeAdd : public NodeParameter
{
public:
	NodeAdd()
	{
		Type = NodeType::Add;
		TypeName = "Add";
		Group = std::vector<std::string>{"Math"};
		Keywords.emplace_back("+");

		InitializeAsIn2Out1Param2();

		BehaviorComponents = {std::make_shared<NodeParameterBehaviorComponentTwoInputMath>()};
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return GetOutputTypeIn2Out1Param2(inputTypes);
	}
	WarningType GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const override
	{
		return GetWarningIn2Out1Param2(material, node);
	}
};

class NodeSubtract : public NodeParameter
{
public:
	NodeSubtract()
	{
		Type = NodeType::Subtract;
		TypeName = "Subtract";
		Group = std::vector<std::string>{"Math"};
		Keywords.emplace_back("-");

		InitializeAsIn2Out1Param2();

		BehaviorComponents = {std::make_shared<NodeParameterBehaviorComponentTwoInputMath>()};
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return GetOutputTypeIn2Out1Param2(inputTypes);
	}
	WarningType GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const override
	{
		return GetWarningIn2Out1Param2(material, node);
	}
};

class NodeMultiply : public NodeParameter
{
public:
	NodeMultiply()
	{
		Type = NodeType::Multiply;
		TypeName = "Multiply";
		Group = std::vector<std::string>{"Math"};
		Keywords.emplace_back("*");

		InitializeAsIn2Out1Param2();

		BehaviorComponents = {std::make_shared<NodeParameterBehaviorComponentTwoInputMath>()};
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return GetOutputTypeIn2Out1Param2(inputTypes);
	}
	WarningType GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const override
	{
		return GetWarningIn2Out1Param2(material, node);
	}
};

class NodeDivide : public NodeParameter
{
public:
	NodeDivide()
	{
		Type = NodeType::Divide;
		TypeName = "Divide";
		Group = std::vector<std::string>{"Math"};
		Keywords.emplace_back("/");

		InitializeAsIn2Out1Param2();

		Properties[1]->DefaultValues[0] = 1;

		BehaviorComponents = {std::make_shared<NodeParameterBehaviorComponentTwoInputMath>()};
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return GetOutputTypeIn2Out1Param2(inputTypes);
	}
	WarningType GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const override
	{
		return GetWarningIn2Out1Param2(material, node);
	}
};

class NodeFmod : public NodeParameter
{
public:
	NodeFmod()
	{
		Type = NodeType::FMod;
		TypeName = "Fmod";
		Group = std::vector<std::string>{"Math"};

		InitializeAsIn2Out1Param2();

		Properties[1]->DefaultValues[0] = 1;

		BehaviorComponents = {std::make_shared<NodeParameterBehaviorComponentTwoInputMath>()};
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return GetOutputTypeIn2Out1Param2(inputTypes);
	}
	WarningType GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const override
	{
		return GetWarningIn2Out1Param2(material, node);
	}
};

class NodeStep : public NodeParameter
{
public:
	NodeStep()
	{
		Type = NodeType::Step;
		TypeName = "Step";
		Group = std::vector<std::string>{"Math"};

		auto edge = std::make_shared<PinParameter>();
		edge->Name = "Edge";
		edge->Type = ValueType::Float1;
		edge->DefaultValues[0] = 0.5f;
		InputPins.push_back(edge);

		auto value = std::make_shared<PinParameter>();
		value->Name = "Value";
		value->Type = ValueType::Float1;
		InputPins.push_back(value);

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float1;
		OutputPins.push_back(output);
	}
};

class NodeCeil : public NodeParameter
{
public:
	NodeCeil()
	{
		Type = NodeType::Ceil;
		TypeName = "Ceil";
		Group = std::vector<std::string>{"Math"};

		InitializeAstOutputTypeIn1Out1();
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return GetOutputTypeIn1Out1(inputTypes);
	}
};

class NodeFloor : public NodeParameter
{
public:
	NodeFloor()
	{
		Type = NodeType::Floor;
		TypeName = "Floor";
		Group = std::vector<std::string>{"Math"};

		InitializeAstOutputTypeIn1Out1();
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return GetOutputTypeIn1Out1(inputTypes);
	}
};

class NodeFrac : public NodeParameter
{
public:
	NodeFrac()
	{
		Type = NodeType::Frac;
		TypeName = "Frac";
		Group = std::vector<std::string>{"Math"};

		InitializeAstOutputTypeIn1Out1();
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return GetOutputTypeIn1Out1(inputTypes);
	}
};

class NodeMax : public NodeParameter
{
public:
	NodeMax()
	{
		Type = NodeType::Max;
		TypeName = "Max";
		Group = std::vector<std::string>{"Math"};

		InitializeAsIn2Out1Param2();

		BehaviorComponents = {std::make_shared<NodeParameterBehaviorComponentTwoInputMath>()};
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return GetOutputTypeIn2Out1Param2(inputTypes);
	}
	WarningType GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const override
	{
		return GetWarningIn2Out1Param2(material, node);
	}
};

class NodeMin : public NodeParameter
{
public:
	NodeMin()
	{
		Type = NodeType::Min;
		TypeName = "Min";
		Group = std::vector<std::string>{"Math"};

		InitializeAsIn2Out1Param2();

		BehaviorComponents = {std::make_shared<NodeParameterBehaviorComponentTwoInputMath>()};
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return GetOutputTypeIn2Out1Param2(inputTypes);
	}
	WarningType GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const override
	{
		return GetWarningIn2Out1Param2(material, node);
	}
};

class NodePower : public NodeParameter
{
public:
	NodePower()
	{
		Type = NodeType::Power;
		TypeName = "Power";
		Group = std::vector<std::string>{"Math"};

		auto input1 = std::make_shared<PinParameter>();
		input1->Name = "Base";
		input1->Type = ValueType::FloatN;
		InputPins.push_back(input1);

		auto input2 = std::make_shared<PinParameter>();
		input2->Name = "Exp";
		input2->Type = ValueType::Float1;
		InputPins.push_back(input2);

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::FloatN;
		OutputPins.push_back(output);

		auto paramExp = std::make_shared<NodePropertyParameter>();
		paramExp->Name = "Exp";
		paramExp->Type = ValueType::Float1;
		paramExp->DefaultValues[0] = 2.0f;
		Properties.push_back(paramExp);
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return inputTypes[0];
	}
};

class NodeSquareRoot : public NodeParameter
{
public:
	NodeSquareRoot()
	{
		Type = NodeType::SquareRoot;
		TypeName = "SquareRoot";
		Group = std::vector<std::string>{"Math"};

		InitializeAstOutputTypeIn1Out1();
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return GetOutputTypeIn1Out1(inputTypes);
	}
};

class NodeClamp : public NodeParameter
{
public:
	NodeClamp()
	{
		Type = NodeType::Clamp;
		TypeName = "Clamp";
		Group = std::vector<std::string>{"Math"};

		auto input1 = std::make_shared<PinParameter>();
		input1->Name = "Input";
		input1->Type = ValueType::FloatN;
		InputPins.push_back(input1);

		auto input2 = std::make_shared<PinParameter>();
		input2->Name = "Min";
		input2->Type = ValueType::FloatN;
		InputPins.push_back(input2);

		auto input3 = std::make_shared<PinParameter>();
		input3->Name = "Max";
		input3->Type = ValueType::FloatN;
		InputPins.push_back(input3);

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::FloatN;
		OutputPins.push_back(output);

		auto paramMin = std::make_shared<NodePropertyParameter>();
		paramMin->Name = "Min";
		paramMin->Type = ValueType::Float1;
		Properties.push_back(paramMin);

		auto paramMax = std::make_shared<NodePropertyParameter>();
		paramMax->Name = "Max";
		paramMax->Type = ValueType::Float1;
		paramMax->DefaultValues[0] = 1.0f;
		Properties.push_back(paramMax);
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return inputTypes[0];
	}
};

class NodeDotProduct : public NodeParameter
{
public:
	NodeDotProduct()
	{
		Type = NodeType::DotProduct;
		TypeName = "DotProduct";
		Group = std::vector<std::string>{"Math"};

		auto input1 = std::make_shared<PinParameter>();
		input1->Name = "Value1";
		input1->Type = ValueType::FloatN;
		InputPins.push_back(input1);

		auto input2 = std::make_shared<PinParameter>();
		input2->Name = "Value2";
		input2->Type = ValueType::FloatN;
		InputPins.push_back(input2);

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float1;
		OutputPins.push_back(output);
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return inputTypes[0];
	}
	WarningType GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const override
	{
		std::unordered_set<std::shared_ptr<Pin>> visited1;
		std::unordered_set<std::shared_ptr<Pin>> visited2;

		auto type1 = material->GetDesiredPinType(node->InputPins[0], visited1);
		auto type2 = material->GetDesiredPinType(node->InputPins[1], visited2);
		return type1 == type2 ? WarningType::None : WarningType::WrongInputType;
	}
};

class NodeCrossProduct : public NodeParameter
{
public:
	NodeCrossProduct()
	{
		Type = NodeType::CrossProduct;
		TypeName = "CrossProduct";
		Group = std::vector<std::string>{"Math"};

		auto input1 = std::make_shared<PinParameter>();
		input1->Name = "Value1";
		input1->Type = ValueType::Float3;
		InputPins.push_back(input1);

		auto input2 = std::make_shared<PinParameter>();
		input2->Name = "Value2";
		input2->Type = ValueType::Float3;
		InputPins.push_back(input2);

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float3;
		OutputPins.push_back(output);
	}
};

class NodeNormalize : public NodeParameter
{
public:
	NodeNormalize()
	{
		Type = NodeType::Normalize;
		TypeName = "Normalize";
		Group = std::vector<std::string>{"Math"};

		auto input1 = std::make_shared<PinParameter>();
		input1->Name = "Value";
		input1->Type = ValueType::FloatN;
		InputPins.push_back(input1);

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::FloatN;
		OutputPins.push_back(output);
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return GetOutputTypeIn1Out1(inputTypes);
	}
};

class NodeLinearInterpolate : public NodeParameter
{
public:
	NodeLinearInterpolate()
	{
		Type = NodeType::LinearInterpolate;
		TypeName = "LinearInterpolate";
		Group = std::vector<std::string>{"Math"};
		Keywords.emplace_back("lerp");

		auto input1 = std::make_shared<PinParameter>();
		input1->Name = "Value1";
		input1->Type = ValueType::FloatN;
		InputPins.push_back(input1);

		auto input2 = std::make_shared<PinParameter>();
		input2->Name = "Value2";
		input2->Type = ValueType::FloatN;
		InputPins.push_back(input2);

		auto inputAlpha = std::make_shared<PinParameter>();
		inputAlpha->Name = "Alpha";
		inputAlpha->Type = ValueType::Float1;
		InputPins.push_back(inputAlpha);

		auto input1Prop = std::make_shared<NodePropertyParameter>();
		input1Prop->Name = "Value1";
		input1Prop->Type = ValueType::Float1;
		input1Prop->DefaultValues[0] = 0.0f;
		Properties.push_back(input1Prop);

		auto input2Prop = std::make_shared<NodePropertyParameter>();
		input2Prop->Name = "Value2";
		input2Prop->Type = ValueType::Float1;
		input2Prop->DefaultValues[0] = 1.0f;
		Properties.push_back(input2Prop);

		auto inputAlphaProp = std::make_shared<NodePropertyParameter>();
		inputAlphaProp->Name = "Alpha";
		inputAlphaProp->Type = ValueType::Float1;
		inputAlphaProp->DefaultValues[0] = 0.5f;
		Properties.push_back(inputAlphaProp);

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::FloatN;
		OutputPins.push_back(output);
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override
	{
		return GetOutputTypeIn2Out1Param2(inputTypes);
	}

	WarningType GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const override
	{
		return GetWarningIn2Out1Param2(material, node);
	}
};

class NodeTextureCoordinate : public NodeParameter
{
public:
	NodeTextureCoordinate()
	{
		Type = NodeType::TextureCoordinate;
		TypeName = "TextureCoordinate";
		Group = std::vector<std::string>{"Model"};

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float2;
		OutputPins.push_back(output);

		auto param = std::make_shared<NodePropertyParameter>();
		param->Name = "UVIndex";
		param->Type = ValueType::Enum;
		param->DefaultValues[0] = 0;
		Properties.push_back(param);
	}
};

class NodePanner : public NodeParameter
{
public:
	NodePanner()
	{
		Type = NodeType::Panner;
		TypeName = "Panner";
		Group = std::vector<std::string>{"Model"};

		auto input1 = std::make_shared<PinParameter>();
		input1->Name = "UV";
		input1->Type = ValueType::Float2;
		input1->Default = DefaultType::UV;
		InputPins.push_back(input1);

		auto input2 = std::make_shared<PinParameter>();
		input2->Name = "Time";
		input2->Type = ValueType::Float1;
		input2->Default = DefaultType::Time;
		InputPins.push_back(input2);

		auto input3 = std::make_shared<PinParameter>();
		input3->Name = "Speed";
		input3->Type = ValueType::Float2;
		InputPins.push_back(input3);

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float2;
		OutputPins.push_back(output);

		auto val1 = std::make_shared<NodePropertyParameter>();
		val1->Name = "Speed";
		val1->Type = ValueType::Float2;
		Properties.push_back(val1);

		auto param = std::make_shared<NodePropertyParameter>();
		param->Name = "UVIndex";
		param->Type = ValueType::Enum;
		param->DefaultValues[0] = 0;
		Properties.push_back(param);
	}
};

class NodeTextureObject : public NodeParameter
{
public:
	NodeTextureObject()
	{
		Type = NodeType::TextureObject;
		TypeName = "TextureObject";
		Group = std::vector<std::string>{"Texture"};

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Texture;
		OutputPins.push_back(output);

		auto param = std::make_shared<NodePropertyParameter>();
		param->Name = "Texture";
		param->Type = ValueType::Texture;
		Properties.push_back(param);
	}
};

class NodeTextureObjectParameter : public NodeParameter
{
public:
	NodeTextureObjectParameter()
	{
		Type = NodeType::TextureObjectParameter;
		TypeName = "TextureObjectParameter";
		Group = std::vector<std::string>{"Texture"};
		HasDescription = true;
		IsDescriptionExported = true;

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Texture;
		OutputPins.push_back(output);

		auto paramName = std::make_shared<NodePropertyParameter>();
		paramName->Name = "Name";
		paramName->Type = ValueType::String;
		paramName->DefaultStr = "Noname";
		Properties.push_back(paramName);

		auto paramPriority = std::make_shared<NodePropertyParameter>();
		paramPriority->Name = "Priority";
		paramPriority->Type = ValueType::Int;
		paramPriority->DefaultValues[0] = 1;
		Properties.push_back(paramPriority);

		auto param = std::make_shared<NodePropertyParameter>();
		param->Name = "Texture";
		param->Type = ValueType::Texture;
		Properties.push_back(param);

		BehaviorComponents = {std::make_shared<NodeParameterBehaviorComponentParameter>()};
	}
};

class NodeSampleTexture : public NodeParameter
{
public:
	NodeSampleTexture()
	{
		Type = NodeType::SampleTexture;
		TypeName = "SampleTexture";
		Group = std::vector<std::string>{"Texture"};

		auto inputTexture = std::make_shared<PinParameter>();
		inputTexture->Name = "Texture";
		inputTexture->Type = ValueType::Texture;
		InputPins.push_back(inputTexture);

		auto inputUV = std::make_shared<PinParameter>();
		inputUV->Name = "UV";
		inputUV->Type = ValueType::Float2;
		inputUV->Default = DefaultType::UV;
		InputPins.push_back(inputUV);

		auto rgb = std::make_shared<PinParameter>();
		rgb->Name = "RGB";
		rgb->Type = ValueType::Float3;
		OutputPins.push_back(rgb);

		auto r = std::make_shared<PinParameter>();
		r->Name = "R";
		r->Type = ValueType::Float1;
		OutputPins.push_back(r);

		auto g = std::make_shared<PinParameter>();
		g->Name = "G";
		g->Type = ValueType::Float1;
		OutputPins.push_back(g);

		auto b = std::make_shared<PinParameter>();
		b->Name = "B";
		b->Type = ValueType::Float1;
		OutputPins.push_back(b);

		auto a = std::make_shared<PinParameter>();
		a->Name = "A";
		a->Type = ValueType::Float1;
		OutputPins.push_back(a);

		auto rgba = std::make_shared<PinParameter>();
		rgba->Name = "RGBA";
		rgba->Type = ValueType::Float4;
		OutputPins.push_back(rgba);

		// compatibility
		// auto output = std::make_shared<PinParameter>();
		// output->Name = "Output";
		// output->Type = ValueType::Float4;
		// OutputPins.push_back(output);

		auto param = std::make_shared<NodePropertyParameter>();
		param->Name = "Texture";
		param->Type = ValueType::Texture;
		Properties.push_back(param);

		auto paramSampler = std::make_shared<NodePropertyParameter>();
		paramSampler->Name = "Sampler";
		paramSampler->Type = ValueType::Enum;
		paramSampler->DefaultValues[0] = 0;
		Properties.push_back(paramSampler);

		IsPreviewOpened = true;
	}

	WarningType GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const
	{
		return GetWarningSampler(material, node);
	}
};

class NodeTime : public NodeParameter
{
public:
	NodeTime()
	{
		Type = NodeType::Time;
		TypeName = "Time";
		Group = std::vector<std::string>{"Constant"};

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float1;
		OutputPins.push_back(output);
	}
};

class NodeEffectScale : public NodeParameter
{
public:
	NodeEffectScale()
	{
		Type = NodeType::EffectScale;
		TypeName = "EffectScale";
		Group = std::vector<std::string>{"Constant"};

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float1;
		OutputPins.push_back(output);
	}
};

class NodeCameraPositionWS : public NodeParameter
{
public:
	NodeCameraPositionWS()
	{
		Type = NodeType::CameraPositionWS;
		TypeName = "CameraPositionWS";
		Group = std::vector<std::string>{"Constant"};

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float3;
		OutputPins.push_back(output);
	}
};

class NodeVertexNormalWS : public NodeParameter
{
public:
	NodeVertexNormalWS()
	{
		Type = NodeType::VertexNormalWS;
		TypeName = "VertexNormalWS";
		Group = std::vector<std::string>{"Model"};

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float3;
		OutputPins.push_back(output);
	}
};

class NodePixelNormalWS : public NodeParameter
{
public:
	NodePixelNormalWS()
	{
		Type = NodeType::PixelNormalWS;
		TypeName = "PixelNormalWS";
		Group = std::vector<std::string>{"Model"};

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float3;
		OutputPins.push_back(output);
	}

	WarningType GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const;
};

class NodeWorldPosition : public NodeParameter
{
public:
	NodeWorldPosition()
	{
		Type = NodeType::WorldPosition;
		TypeName = "WorldPosition";
		Group = std::vector<std::string>{"Model"};

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float3;
		OutputPins.push_back(output);
	}
};

class NodeVertexColor : public NodeParameter
{
public:
	NodeVertexColor()
	{
		Type = NodeType::VertexColor;
		TypeName = "VertexColor";
		Group = std::vector<std::string>{"Model"};

		auto rgb = std::make_shared<PinParameter>();
		rgb->Name = "RGB";
		rgb->Type = ValueType::Float3;
		OutputPins.push_back(rgb);

		auto r = std::make_shared<PinParameter>();
		r->Name = "R";
		r->Type = ValueType::Float1;
		OutputPins.push_back(r);

		auto g = std::make_shared<PinParameter>();
		g->Name = "G";
		g->Type = ValueType::Float1;
		OutputPins.push_back(g);

		auto b = std::make_shared<PinParameter>();
		b->Name = "B";
		b->Type = ValueType::Float1;
		OutputPins.push_back(b);

		auto a = std::make_shared<PinParameter>();
		a->Name = "A";
		a->Type = ValueType::Float1;
		OutputPins.push_back(a);
	}
};

class NodeObjectScale : public NodeParameter
{
public:
	NodeObjectScale()
	{
		Type = NodeType::ObjectScale;
		TypeName = "ObjectScale";
		Group = std::vector<std::string>{"Model"};

		auto output = std::make_shared<PinParameter>();
		output->Name = "XYZ";
		output->Type = ValueType::Float3;
		OutputPins.push_back(output);
	}
};

class NodeDepthFade : public NodeParameter
{
public:
	NodeDepthFade()
	{
		Type = NodeType::DepthFade;
		TypeName = "DepthFade";
		Group = std::vector<std::string>{"Depth"};

		auto inputFadeDistance = std::make_shared<PinParameter>();
		inputFadeDistance->Name = "FadeDistance";
		inputFadeDistance->Type = ValueType::Float1;
		InputPins.push_back(inputFadeDistance);

		auto inputFadeDistanceProp = std::make_shared<NodePropertyParameter>();
		inputFadeDistanceProp->Name = "FadeDistance";
		inputFadeDistanceProp->Type = ValueType::Float1;
		inputFadeDistanceProp->DefaultValues[0] = 0.0f;
		Properties.push_back(inputFadeDistanceProp);


		auto output = std::make_shared<PinParameter>();
		output->Name = "Opacity";
		output->Type = ValueType::Float1;
		OutputPins.push_back(output);
	}
};


#ifdef _DEBUG
class NodeVertexTangentWS : public NodeParameter
{
public:
	NodeVertexTangentWS()
	{
		Type = NodeType::VertexTangentWS;
		TypeName = "VertexTangentWS";
		Group = std::vector<std::string>{"Model"};

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float3;
		OutputPins.push_back(output);
	}
};
#endif

class NodeCustomData1 : public NodeParameter
{
public:
	NodeCustomData1()
	{
		Type = NodeType::CustomData1;
		TypeName = "CustomData1";
		Group = std::vector<std::string>{"Parameter"};
		HasDescription = true;

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::FloatN;
		OutputPins.push_back(output);

		auto val1 = std::make_shared<NodePropertyParameter>();
		val1->Name = "R";
		val1->Type = ValueType::Bool;
		val1->DefaultValues[0] = 1.0f;
		Properties.push_back(val1);

		auto val2 = std::make_shared<NodePropertyParameter>();
		val2->Name = "G";
		val2->Type = ValueType::Bool;
		val2->DefaultValues[0] = 1.0f;
		Properties.push_back(val2);

		auto val3 = std::make_shared<NodePropertyParameter>();
		val3->Name = "B";
		val3->Type = ValueType::Bool;
		Properties.push_back(val3);

		auto val4 = std::make_shared<NodePropertyParameter>();
		val4->Name = "A";
		val4->Type = ValueType::Bool;
		Properties.push_back(val4);

		BehaviorComponents = {std::make_shared<NodeParameterBehaviorComponentMask>()};
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override;
};

class NodeCustomData2 : public NodeParameter
{
public:
	NodeCustomData2()
	{
		Type = NodeType::CustomData2;
		TypeName = "CustomData2";
		Group = std::vector<std::string>{"Parameter"};
		HasDescription = true;

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::FloatN;
		OutputPins.push_back(output);

		auto val1 = std::make_shared<NodePropertyParameter>();
		val1->Name = "R";
		val1->Type = ValueType::Bool;
		val1->DefaultValues[0] = 1.0f;
		Properties.push_back(val1);

		auto val2 = std::make_shared<NodePropertyParameter>();
		val2->Name = "G";
		val2->Type = ValueType::Bool;
		val2->DefaultValues[0] = 1.0f;
		Properties.push_back(val2);

		auto val3 = std::make_shared<NodePropertyParameter>();
		val3->Name = "B";
		val3->Type = ValueType::Bool;
		Properties.push_back(val3);

		auto val4 = std::make_shared<NodePropertyParameter>();
		val4->Name = "A";
		val4->Type = ValueType::Bool;
		Properties.push_back(val4);

		BehaviorComponents = {std::make_shared<NodeParameterBehaviorComponentMask>()};
	}

	ValueType
	GetOutputType(std::shared_ptr<Material> material, std::shared_ptr<Node> node, const std::vector<ValueType>& inputTypes) const override;
};

class NodeFresnel : public NodeParameter
{
public:
	NodeFresnel()
	{
		Type = NodeType::Fresnel;
		TypeName = "Fresnel";
		Group = std::vector<std::string>{"Advanced"};

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float1;
		OutputPins.push_back(output);

		auto exponentPin = std::make_shared<PinParameter>();
		exponentPin->Name = "Exponent";
		exponentPin->Type = ValueType::Float1;
		InputPins.push_back(exponentPin);

		auto baseReflectFractionPin = std::make_shared<PinParameter>();
		baseReflectFractionPin->Name = "BaseReflectFraction";
		baseReflectFractionPin->Type = ValueType::Float1;
		InputPins.push_back(baseReflectFractionPin);

		auto val1 = std::make_shared<NodePropertyParameter>();
		val1->Name = "Exponent";
		val1->Type = ValueType::Float1;
		val1->DefaultValues[0] = 5.0f;
		Properties.push_back(val1);

		auto val2 = std::make_shared<NodePropertyParameter>();
		val2->Name = "BaseReflectFraction";
		val2->Type = ValueType::Float1;
		val2->DefaultValues[0] = 0.04f;
		Properties.push_back(val2);
	}
};

class NodeRotator : public NodeParameter
{
public:
	NodeRotator()
	{
		Type = NodeType::Rotator;
		TypeName = "Rotator";
		Group = std::vector<std::string>{"Advanced"};

		auto output = std::make_shared<PinParameter>();
		output->Name = "Output";
		output->Type = ValueType::Float2;
		OutputPins.push_back(output);

		auto uvPin = std::make_shared<PinParameter>();
		uvPin->Name = "UV";
		uvPin->Type = ValueType::Float2;
		InputPins.push_back(uvPin);

		auto centerPin = std::make_shared<PinParameter>();
		centerPin->Name = "RotationCenter";
		centerPin->Type = ValueType::Float2;
		InputPins.push_back(centerPin);

		auto anglePin = std::make_shared<PinParameter>();
		anglePin->Name = "RotationAngle";
		anglePin->Type = ValueType::Float1;
		InputPins.push_back(anglePin);
	}
};

class NodePolarCoords : public NodeParameter
{
public:
	NodePolarCoords()
	{
		Type = NodeType::PolarCoords;
		TypeName = "PolarCoords";
		Group = std::vector<std::string>{"Advanced"};

		auto tilePin = std::make_shared<PinParameter>();
		tilePin->Name = "Tile";
		tilePin->Type = ValueType::Float2;
		tilePin->DefaultValues[0] = 1.0f;
		tilePin->DefaultValues[1] = 1.0f;
		InputPins.push_back(tilePin);

		auto offsetPin = std::make_shared<PinParameter>();
		offsetPin->Name = "Offset";
		offsetPin->Type = ValueType::Float2;
		offsetPin->DefaultValues[0] = 0.0f;
		offsetPin->DefaultValues[1] = 0.0f;
		InputPins.push_back(offsetPin);

		auto pitchVPin = std::make_shared<PinParameter>();
		pitchVPin->Name = "PitchV";
		pitchVPin->Type = ValueType::Float1;
		pitchVPin->DefaultValues[0] = 1.0f;
		InputPins.push_back(pitchVPin);

		auto val1 = std::make_shared<NodePropertyParameter>();
		val1->Name = "Tile";
		val1->Type = ValueType::Float2;
		val1->DefaultValues[0] = 1.0f;
		val1->DefaultValues[1] = 1.0f;
		Properties.push_back(val1);

		auto val2 = std::make_shared<NodePropertyParameter>();
		val2->Name = "Offset";
		val2->Type = ValueType::Float2;
		val2->DefaultValues[0] = 0.0f;
		Properties.push_back(val2);

		auto val3 = std::make_shared<NodePropertyParameter>();
		val3->Name = "PitchV";
		val3->Type = ValueType::Float1;
		val3->DefaultValues[0] = 1.0f;
		Properties.push_back(val3);

		auto output = std::make_shared<PinParameter>();
		output->Name = "RadicalCoordinates";
		output->Type = ValueType::Float2;
		OutputPins.push_back(output);
	}
};

class NodeComment : public NodeParameter
{
public:
	NodeComment()
	{
		Type = NodeType::Comment;
		TypeName = "Comment";

		auto paramName = std::make_shared<NodePropertyParameter>();
		paramName->Name = "Comment";
		paramName->Type = ValueType::String;
		Properties.push_back(paramName);
	}
};

class NodeFunction : public NodeParameter
{
public:
	NodeFunction()
	{
		Type = NodeType::Function;
		TypeName = "Function";

		auto paramName = std::make_shared<NodePropertyParameter>();
		paramName->Name = "Name";
		paramName->Type = ValueType::Function;
		Properties.push_back(paramName);
	}
};

class NodeOutput : public NodeParameter
{
public:
	NodeOutput()
	{
		Type = NodeType::Output;
		TypeName = "Output";
		IsPreviewOpened = true;
		HasDescription = true;
		IsDescriptionExported = true;

		auto baseColor = std::make_shared<PinParameter>();
		baseColor->Name = "BaseColor";
		baseColor->Type = ValueType::Float3;
		baseColor->Default = DefaultType::Value;
		// baseColor->DefaultValues.fill(0.5f);
		baseColor->DefaultValues[3] = 1.0f;
		InputPins.push_back(baseColor);

		auto emissive = std::make_shared<PinParameter>();
		emissive->Name = "Emissive";
		emissive->Type = ValueType::Float3;
		emissive->Default = DefaultType::Value;
		// emissive->DefaultValues.fill(0.5f);
		emissive->DefaultValues[3] = 1.0f;
		InputPins.push_back(emissive);

		auto opacity = std::make_shared<PinParameter>();
		opacity->Name = "Opacity";
		opacity->Type = ValueType::Float1;
		opacity->Default = DefaultType::Value;
		opacity->DefaultValues.fill(1.0f);
		InputPins.push_back(opacity);

		auto opacityMask = std::make_shared<PinParameter>();
		opacityMask->Name = "OpacityMask";
		opacityMask->Type = ValueType::Float1;
		opacityMask->Default = DefaultType::Value;
		opacityMask->DefaultValues.fill(1.0f);
		InputPins.push_back(opacityMask);

		auto normal = std::make_shared<PinParameter>();
		normal->Name = "Normal";
		normal->Type = ValueType::Float3;
		normal->Default = DefaultType::Value;
		normal->DefaultValues.fill(0.5f);
		normal->DefaultValues[2] = 1.0f;
		InputPins.push_back(normal);

		auto metallic = std::make_shared<PinParameter>();
		metallic->Name = "Metallic";
		metallic->Type = ValueType::Float1;
		metallic->Default = DefaultType::Value;
		metallic->DefaultValues.fill(0.5f);
		InputPins.push_back(metallic);

		auto roughness = std::make_shared<PinParameter>();
		roughness->Name = "Roughness";
		roughness->Type = ValueType::Float1;
		roughness->Default = DefaultType::Value;
		roughness->DefaultValues.fill(0.5f);
		InputPins.push_back(roughness);

		auto ambientOcclusion = std::make_shared<PinParameter>();
		ambientOcclusion->Name = "AmbientOcclusion";
		ambientOcclusion->Type = ValueType::Float1;
		ambientOcclusion->Default = DefaultType::Value;
		ambientOcclusion->DefaultValues.fill(1.0f);
		InputPins.push_back(ambientOcclusion);

		auto refraction = std::make_shared<PinParameter>();
		refraction->Name = "Refraction";
		refraction->Type = ValueType::Float1;
		refraction->Default = DefaultType::Value;
		refraction->DefaultValues.fill(0.0f);
		InputPins.push_back(refraction);

		auto worldPositionOffset = std::make_shared<PinParameter>();
		worldPositionOffset->Name = "WorldPositionOffset";
		worldPositionOffset->Type = ValueType::Float3;
		worldPositionOffset->Default = DefaultType::Value;
		worldPositionOffset->DefaultValues.fill(0.0f);
		InputPins.push_back(worldPositionOffset);

		auto shadingProperty = std::make_shared<NodePropertyParameter>();
		shadingProperty->Name = "ShadingModel";
		shadingProperty->Type = ValueType::Enum;
		shadingProperty->DefaultValues.fill(1.0f);
		Properties.push_back(shadingProperty);

		BehaviorComponents = {std::make_shared<NodeParameterBehaviorComponentOutput>()};
	}
};
} // namespace EffekseerMaterial
