#include "efkMat.Parameters.h"
#include "efkMat.Models.h"
#include "efkMat.StringContainer.h"

namespace EffekseerMaterial
{

ValueType InferOutputTypeIn1Out1(const std::vector<ValueType>& inputTypes) { return inputTypes[0]; }

ValueType InferOutputTypeIn2Out1Param2(const std::vector<ValueType>& inputTypes)
{
	if (inputTypes[0] == ValueType::Float1)
		return inputTypes[1];

	if (inputTypes[1] == ValueType::Float1)
		return inputTypes[0];

	return inputTypes[0];
}

ValueType InferOutputTypeInAppendVector(const std::vector<ValueType>& inputTypes)
{
	int counter = 0;

	auto count = std::min(4, GetElementCount(inputTypes[0]) + GetElementCount(inputTypes[1]));

	return static_cast<ValueType>(static_cast<int>(ValueType::Float1) + count - 1);
}

std::string NodeParameterBehaviorComponentTwoInputMath::GetHeader(std::shared_ptr<Material> material,
																  std::shared_ptr<NodeParameter> parameter,
																  std::shared_ptr<Node> node) const
{
	std::ostringstream ret;
	ret << StringContainer::GetValue((parameter->TypeName + "_Node_Name").c_str(), parameter->TypeName.c_str());
	ret << "(";

	if (material->GetConnectedPins(node->InputPins[0]).size() > 0)
	{
	}
	else
	{
		ret << node->Properties[0]->Floats[0];
	}

	ret << ",";

	if (material->GetConnectedPins(node->InputPins[1]).size() > 0)
	{
	}
	else
	{
		ret << node->Properties[1]->Floats[0];
	}

	ret << ")";

	return ret.str();
}

std::string NodeParameterBehaviorComponentMask::GetHeader(std::shared_ptr<Material> material,
														  std::shared_ptr<NodeParameter> parameter,
														  std::shared_ptr<Node> node) const
{
	std::ostringstream ret;
	ret << StringContainer::GetValue((parameter->TypeName + "_Node_Name").c_str(), parameter->TypeName.c_str());
	ret << "(";

	if (node->Properties[0]->Floats[0] > 0)
		ret << "R";

	if (node->Properties[1]->Floats[0] > 0)
		ret << "G";

	if (node->Properties[2]->Floats[0] > 0)
		ret << "B";

	if (node->Properties[3]->Floats[0] > 0)
		ret << "A";

	ret << ")";

	return ret.str();
}

std::string NodeParameterBehaviorComponentParameter::GetHeader(std::shared_ptr<Material> material,
															   std::shared_ptr<NodeParameter> parameter,
															   std::shared_ptr<Node> node) const
{
	std::ostringstream ret;

	assert(node->Parameter->Properties[0]->Name == "Name");

	ret << StringContainer::GetValue((parameter->TypeName + "_Node_Name").c_str(), parameter->TypeName.c_str());
	ret << "(";
	ret << node->Properties[0]->Str;
	ret << ")";

	return ret.str();
}

WarningType NodeParameterBehaviorComponentParameter::GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const
{
	assert(node->Parameter->Properties[0]->Name == "Name");

	if (!IsValidName(node->Properties[0]->Str.c_str()))
	{
		return WarningType::InvalidName;
	}

	for (auto& n : material->GetNodes())
	{
		if (node == n)
			continue;

		if (n->Parameter->Type == NodeType::Parameter1 || n->Parameter->Type == NodeType::Parameter2 ||
			n->Parameter->Type == NodeType::Parameter3 || n->Parameter->Type == NodeType::Parameter4 ||
			n->Parameter->Type == NodeType::TextureObjectParameter)
		{
			if (node->Properties[0]->Str == n->Properties[0]->Str)
			{
				return WarningType::SameName;
			}
		}
	}

	return WarningType::None;
}

std::string NodeParameterBehaviorConstantName::GetHeader(std::shared_ptr<Material> material,
														 std::shared_ptr<NodeParameter> parameter,
														 std::shared_ptr<Node> node) const
{
	std::ostringstream ret;

	for (int32_t i = 0; i < componentCount_; i++)
	{
		ret << node->Properties[0]->Floats[i];

		if (componentCount_ - 1 != i)
		{
			ret << ",";
		}
	}

	return ret.str();
}

bool NodeParameterBehaviorComponentOutput::GetIsInputPinEnabled(std::shared_ptr<Material> material,
																std::shared_ptr<NodeParameter> parameter,
																std::shared_ptr<Node> node,
																std::shared_ptr<Pin> pin)
{
	assert(node->Parameter->Properties[0]->Name == "ShadingModel");

	auto shadingModel = (ShadingModelType)(int)node->Properties[0]->Floats[0];

	if (shadingModel == ShadingModelType::Lit)
	{
		return true;
	}

	if (pin->Parameter->Name != "BaseColor" && pin->Parameter->Name != "Roughness" && pin->Parameter->Name != "Metallic")
	{
		return true;
	}

	return false;
}

std::string NodeParameter::GetHeader(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const
{
	return StringContainer::GetValue((TypeName + "_Node_Name").c_str(), TypeName.c_str());
}

bool ExtractTextureParameter(std::shared_ptr<Material> material, std::shared_ptr<Node> node, ExtractedTextureParameter& result)
{

	if (node->Parameter->Type == NodeType::SampleTexture)
	{
		auto texPin = node->InputPins[0];
		auto texProp = node->Properties[0];
		auto sampleProp = node->Properties[1];

		auto connected = material->GetConnectedPins(texPin);

		if (connected.size() > 0)
		{
			auto parent = connected[0]->Parent.lock();
			ExtractTextureParameter(material, parent, result);
			result.Sampler = static_cast<TextureSamplerType>((int32_t)sampleProp->Floats[0]);
			return true;
		}
		else
		{
			result.Path = texProp->Str;
			result.Sampler = static_cast<TextureSamplerType>((int32_t)sampleProp->Floats[0]);
			return true;
		}
	}
	else if (node->Parameter->Type == NodeType::TextureObject)
	{
		auto texProp = node->Properties[0];
		result.Path = texProp->Str;
		result.Sampler = TextureSamplerType::Unknown;
		return true;
	}
	else if (node->Parameter->Type == NodeType::TextureObjectParameter)
	{
		auto texProp = node->Properties[0];
		result.GUID = node->GUID;
		result.Sampler = TextureSamplerType::Unknown;
		return true;
	}

	return false;
}

ValueType NodeParameter::GetOutputTypeIn1Out1(const std::vector<ValueType>& inputTypes) const { return inputTypes[0]; }

ValueType NodeParameter::GetOutputTypeIn2Out1Param2(const std::vector<ValueType>& inputTypes) const
{
	if (inputTypes[0] == ValueType::Float1)
		return inputTypes[1];

	if (inputTypes[1] == ValueType::Float1)
		return inputTypes[0];

	return inputTypes[0];
}

WarningType NodeParameter::GetWarningIn2Out1Param2(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const
{
	std::unordered_set<std::shared_ptr<Pin>> visited1;
	std::unordered_set<std::shared_ptr<Pin>> visited2;

	auto type1 = material->GetDesiredPinType(node->InputPins[0], visited1);
	auto type2 = material->GetDesiredPinType(node->InputPins[1], visited2);

	if (type1 == ValueType::Float1)
		return WarningType::None;

	if (type2 == ValueType::Float1)
		return WarningType::None;

	return type1 == type2 ? WarningType::None : WarningType::WrongInputType;
}

WarningType NodeParameter::GetWarningSampler(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const
{

	if (node->Parameter->Type == NodeType::SampleTexture)
	{
		// collect textures

		ExtractedTextureParameter currentParam;
		ExtractTextureParameter(material, node, currentParam);

		for (auto& n : material->GetNodes())
		{
			ExtractedTextureParameter param;
			if (ExtractTextureParameter(material, n, param))
			{
				if (param.Sampler == TextureSamplerType::Unknown)
					continue;

				if (currentParam.Path == param.Path && currentParam.Path != "")
				{
					if (param.Sampler != currentParam.Sampler)
					{
						return WarningType::DifferentSampler;
					}
				}

				if (currentParam.GUID == param.GUID && param.GUID != 0)
				{
					if (param.Sampler != currentParam.Sampler)
					{
						return WarningType::DifferentSampler;
					}
				}
			}
		}

		return WarningType::None;
	}
	else
	{
		assert(0);
	}

	return WarningType::None;
}

NodeConstant1::NodeConstant1()
{
	Type = NodeType::Constant1;
	TypeName = "Constant1";
	Description = "Constant value...";
	Group = std::vector<std::string>{"Constant"};

	auto output = std::make_shared<PinParameter>();
	output->Name = "Output";
	output->Type = ValueType::Float1;
	OutputPins.push_back(output);

	auto param = std::make_shared<NodePropertyParameter>();
	param->Name = "Value";
	param->Type = ValueType::Float1;
	Properties.push_back(param);

	auto func1 = std::make_shared<NodeFunctionParameter>();
	func1->Name = "ConvertParam";
	func1->Func = [](std::shared_ptr<Material> material, std::shared_ptr<Node> node) -> bool {
		auto param = std::make_shared<NodeParameter1>();
		auto new_node = material->CreateNode(param, false);
		auto links = material->GetConnectedPins(node->OutputPins[0]);

		for (auto link : links)
		{
			material->ConnectPin(new_node->OutputPins[0], link);
		}

		new_node->MakePosDirtied();
		new_node->Pos = node->Pos;
		new_node->Properties[new_node->Parameter->GetPropertyIndex("Value")]->Floats = node->Properties[0]->Floats;
		material->RemoveNode(node);
		return true;
	};

	Funcs.push_back(func1);

	BehaviorComponents = {std::make_shared<NodeParameterBehaviorConstantName>(1)};
}

NodeConstant2::NodeConstant2()
{
	Type = NodeType::Constant2;
	TypeName = "Constant2";
	Description = "Constant value...";
	Group = std::vector<std::string>{"Constant"};

	auto output = std::make_shared<PinParameter>();
	output->Name = "Output";
	output->Type = ValueType::Float2;
	OutputPins.push_back(output);

	auto param = std::make_shared<NodePropertyParameter>();
	param->Name = "Value";
	param->Type = ValueType::Float2;
	Properties.push_back(param);

	auto func1 = std::make_shared<NodeFunctionParameter>();
	func1->Name = "ConvertParam";
	func1->Func = [](std::shared_ptr<Material> material, std::shared_ptr<Node> node) -> bool {
		auto param = std::make_shared<NodeParameter2>();
		auto new_node = material->CreateNode(param, false);
		auto links = material->GetConnectedPins(node->OutputPins[0]);

		for (auto link : links)
		{
			material->ConnectPin(new_node->OutputPins[0], link);
		}

		new_node->MakePosDirtied();
		new_node->Pos = node->Pos;
		new_node->Properties[new_node->Parameter->GetPropertyIndex("Value")]->Floats = node->Properties[0]->Floats;
		material->RemoveNode(node);
		return true;
	};

	Funcs.push_back(func1);

	BehaviorComponents = {std::make_shared<NodeParameterBehaviorConstantName>(2)};
}

NodeConstant3::NodeConstant3()
{
	Type = NodeType::Constant3;
	TypeName = "Constant3";
	Description = "Constant value...";
	Group = std::vector<std::string>{"Constant"};

	auto output = std::make_shared<PinParameter>();
	output->Name = "Output";
	output->Type = ValueType::Float3;
	OutputPins.push_back(output);

	auto param = std::make_shared<NodePropertyParameter>();
	param->Name = "Value";
	param->Type = ValueType::Float3;
	Properties.push_back(param);

	auto func1 = std::make_shared<NodeFunctionParameter>();
	func1->Name = "ConvertParam";
	func1->Func = [](std::shared_ptr<Material> material, std::shared_ptr<Node> node) -> bool {
		auto param = std::make_shared<NodeParameter3>();
		auto new_node = material->CreateNode(param, false);
		auto links = material->GetConnectedPins(node->OutputPins[0]);

		for (auto link : links)
		{
			material->ConnectPin(new_node->OutputPins[0], link);
		}

		new_node->MakePosDirtied();
		new_node->Pos = node->Pos;
		new_node->Properties[new_node->Parameter->GetPropertyIndex("Value")]->Floats = node->Properties[0]->Floats;
		material->RemoveNode(node);
		return true;
	};

	Funcs.push_back(func1);

	BehaviorComponents = {std::make_shared<NodeParameterBehaviorConstantName>(3)};
}

NodeConstant4::NodeConstant4()
{
	Type = NodeType::Constant4;
	TypeName = "Constant4";
	Description = "Constant value...";
	Group = std::vector<std::string>{"Constant"};

	auto output = std::make_shared<PinParameter>();
	output->Name = "Output";
	output->Type = ValueType::Float4;
	OutputPins.push_back(output);

	auto param = std::make_shared<NodePropertyParameter>();
	param->Name = "Value";
	param->Type = ValueType::Float4;
	Properties.push_back(param);

	auto func1 = std::make_shared<NodeFunctionParameter>();
	func1->Name = "ConvertParam";
	func1->Func = [](std::shared_ptr<Material> material, std::shared_ptr<Node> node) -> bool {
		auto param = std::make_shared<NodeParameter4>();
		auto new_node = material->CreateNode(param, false);
		auto links = material->GetConnectedPins(node->OutputPins[0]);

		for (auto link : links)
		{
			material->ConnectPin(new_node->OutputPins[0], link);
		}

		new_node->MakePosDirtied();
		new_node->Pos = node->Pos;
		new_node->Properties[new_node->Parameter->GetPropertyIndex("Value")]->Floats = node->Properties[0]->Floats;
		material->RemoveNode(node);
		return true;
	};

	Funcs.push_back(func1);

	BehaviorComponents = {std::make_shared<NodeParameterBehaviorConstantName>(4)};
}

ValueType NodeComponentMask::GetOutputType(std::shared_ptr<Material> material,
										   std::shared_ptr<Node> node,
										   const std::vector<ValueType>& inputTypes) const
{
	int counter = 0;
	for (int i = 0; i < 4; i++)
	{
		if (node->Properties[i]->Floats[0] > 0)
			counter++;
	}

	if (counter == 1)
		return ValueType::Float1;

	if (counter == 2)
		return ValueType::Float2;

	if (counter == 3)
		return ValueType::Float3;

	if (counter == 4)
		return ValueType::Float4;
	return ValueType::Float1;
}

WarningType NodeComponentMask::GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const
{
	int counter = 0;
	for (int i = 0; i < 4; i++)
	{
		if (node->Properties[i]->Floats[0] > 0)
			counter++;
	}
	if (counter == 0)
		return WarningType::WrongProperty;

	std::unordered_set<std::shared_ptr<Pin>> visited;

	auto type1 = material->GetDesiredPinType(node->InputPins[0], visited);

	if (type1 == ValueType::Float1)
		return WarningType::None;

	if (type1 == ValueType::Float2 && (node->Properties[2]->Floats[2] > 0 || node->Properties[3]->Floats[3] > 0))
		return WarningType::WrongInputType;

	if (type1 == ValueType::Float3 && (node->Properties[1]->Floats[3] > 0))
		return WarningType::WrongInputType;

	return WarningType::None;
}

ValueType NodeAppendVector::GetOutputType(std::shared_ptr<Material> material,
										  std::shared_ptr<Node> node,
										  const std::vector<ValueType>& inputTypes) const
{
	std::unordered_set<std::shared_ptr<Pin>> visited1;
	std::unordered_set<std::shared_ptr<Pin>> visited2;

	auto type1 = material->GetDesiredPinType(node->InputPins[0], visited1);
	auto type2 = material->GetDesiredPinType(node->InputPins[1], visited2);

	return InferOutputTypeInAppendVector({type1, type2});
}

WarningType NodeAppendVector::GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const
{
	auto connected1 = material->GetConnectedPins(node->InputPins[0]);
	auto connected2 = material->GetConnectedPins(node->InputPins[1]);

	if (connected1.size() == 0)
		return WarningType::WrongInputType;

	if (connected2.size() == 0)
		return WarningType::WrongInputType;

	std::unordered_set<std::shared_ptr<Pin>> visited1;
	std::unordered_set<std::shared_ptr<Pin>> visited2;

	auto type1 = material->GetDesiredPinType(node->InputPins[0], visited1);
	auto type2 = material->GetDesiredPinType(node->InputPins[1], visited2);

	if (GetElementCount(type1) + GetElementCount(type2) > 4)
	{
		return WarningType::WrongInputType;
	}

	return WarningType::None;
}

WarningType NodePixelNormalWS::GetWarning(std::shared_ptr<Material> material, std::shared_ptr<Node> node) const {

	auto pins = material->GetRelatedPins(node->OutputPins[0]);
	
	for (auto& pin : pins)
	{
		auto node = pin->Parent.lock();
		if (node != nullptr && node->Parameter->Type == NodeType::Output && pin->Parameter->Name == "Normal")
		{
			return WarningType::PixelNodeAndNormal;		
		}
	}

	return WarningType::None;
}

ValueType NodeCustomData1::GetOutputType(std::shared_ptr<Material> material,
										 std::shared_ptr<Node> node,
										 const std::vector<ValueType>& inputTypes) const
{
	int counter = 0;
	for (int i = 0; i < 4; i++)
	{
		if (node->Properties[i]->Floats[0] > 0)
			counter++;
	}

	if (counter == 1)
		return ValueType::Float1;

	if (counter == 2)
		return ValueType::Float2;

	if (counter == 3)
		return ValueType::Float3;

	if (counter == 4)
		return ValueType::Float4;
	return ValueType::Float1;
}

ValueType NodeCustomData2::GetOutputType(std::shared_ptr<Material> material,
										 std::shared_ptr<Node> node,
										 const std::vector<ValueType>& inputTypes) const
{
	int counter = 0;
	for (int i = 0; i < 4; i++)
	{
		if (node->Properties[i]->Floats[0] > 0)
			counter++;
	}

	if (counter == 1)
		return ValueType::Float1;

	if (counter == 2)
		return ValueType::Float2;

	if (counter == 3)
		return ValueType::Float3;

	if (counter == 4)
		return ValueType::Float4;
	return ValueType::Float1;
}

} // namespace EffekseerMaterial