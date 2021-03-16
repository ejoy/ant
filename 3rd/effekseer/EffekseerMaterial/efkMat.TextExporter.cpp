#include "efkMat.TextExporter.h"
#include "efkMat.Models.h"
#include "efkMat.Parameters.h"
#include "efkMat.Utils.h"

namespace EffekseerMaterial
{

/**
	@brief	Refactor with it
*/
class TextCompiler
{
private:
	struct Variable
	{
		std::string Name;
		ValueType Type;
	};

	TextExporter* exporter_;
	std::ostringstream str_;
	int32_t variableID_ = 0;

	std::unordered_map<int32_t, Variable> variables_;

	int32_t cameraPositionID_ = 0;
	int32_t worldPositionID_ = 0;
	int32_t pixelNormalDirID_ = 0;
	int32_t effectScaleID_ = 0;

	ValueType GetType(int32_t id) const { return variables_.at(id).Type; }

	std::string GetNameWithCast(int32_t id, ValueType type) const
	{
		return exporter_->ConvertType(type, GetType(id), variables_.at(id).Name);
	}

	void ExportVariable(int32_t id, const std::string& content)
	{
		str_ << exporter_->GetTypeName(variables_[id].Type) << " " << variables_[id].Name << " = " << content << ";" << std::endl;
	}

	ValueType Broadcast(ValueType type1, ValueType type2)
	{
		ValueType type = ValueType::Unknown;
		if (type1 == type2)
		{
			type = type1;
		}
		else if (type1 == ValueType::Float1)
		{
			type = type2;
		}
		else if (type2 == ValueType::Float1)
		{
			type = type1;
		}
		return type;
	}

public:
	TextCompiler(TextExporter* exporter) : exporter_(exporter)
	{
		cameraPositionID_ = AddVariable(ValueType::Float3, "cameraPosition.xyz");
		worldPositionID_ = AddVariable(ValueType::Float3, "worldPos");
		pixelNormalDirID_ = AddVariable(ValueType::Float3, "pixelNormalDir");
		effectScaleID_ = AddVariable(ValueType::Float1, "$EFFECTSCALE$");
	}

	std::string GetName(int32_t id) const { return variables_.at(id).Name; }

	void Clear() { str_ = std::ostringstream(); }

	std::string Str() const { return str_.str(); }

	int32_t AddVariable(ValueType type, const std::string& name = "")
	{
		std::string n;
		if (name == "")
		{
			n = exporter_->GenerateTempName();
		}
		else
		{
			n = name;
		}

		auto selfID = variableID_;
		Variable variable;
		variable.Type = type;
		variable.Name = n;
		variables_[selfID] = variable;

		variableID_ += 1;

		return selfID;
	}

	int32_t AddConstant(float value, const std::string& name = "")
	{
		std::array<float, 4> values;
		values.fill(0.0f);
		values[0] = value;
		return AddConstant(ValueType::Float1, values, name);
	}

	int32_t AddConstant(std::array<float, 2> value, const std::string& name = "")
	{
		std::array<float, 4> values;
		values.fill(0.0f);
		values[0] = value[0];
		values[1] = value[1];
		return AddConstant(ValueType::Float2, values, name);
	}

	int32_t AddConstant(ValueType type, std::array<float, 4> values, const std::string& name = "")
	{
		// for opengl es
		auto getNum = [](float f) -> std::string {
			std::ostringstream ret;
			if (f == (int)f)
			{
				ret << f << ".0";
			}
			else
			{
				ret << f;
			}

			return ret.str();
		};

		auto selfID = AddVariable(type, name);

		if (type == ValueType::Float1)
		{
			str_ << exporter_->GetTypeName(variables_[selfID].Type) << " " << variables_[selfID].Name << " = "
				 << exporter_->GetTypeName(variables_[selfID].Type) << "(" << getNum(values[0]) << ");" << std::endl;
		}
		else if (type == ValueType::Float2)
		{
			str_ << exporter_->GetTypeName(variables_[selfID].Type) << " " << variables_[selfID].Name << " = "
				 << exporter_->GetTypeName(variables_[selfID].Type) << "(" << getNum(values[0]) << "," << getNum(values[1]) << ");"
				 << std::endl;
		}
		else if (type == ValueType::Float3)
		{
			str_ << exporter_->GetTypeName(variables_[selfID].Type) << " " << variables_[selfID].Name << " = "
				 << exporter_->GetTypeName(variables_[selfID].Type) << "(" << getNum(values[0]) << "," << getNum(values[1]) << ","
				 << getNum(values[2]) << ");" << std::endl;
		}
		else if (type == ValueType::Float4)
		{
			str_ << exporter_->GetTypeName(variables_[selfID].Type) << " " << variables_[selfID].Name << " = "
				 << exporter_->GetTypeName(variables_[selfID].Type) << "(" << getNum(values[0]) << "," << getNum(values[1]) << ","
				 << getNum(values[2]) << "," << getNum(values[3]) << ");" << std::endl;
		}
		else
		{
			assert(0);
		}

		return selfID;
	}

	int32_t Add(int32_t id1, int32_t id2, const std::string& name = "")
	{
		auto type = InferOutputTypeIn2Out1Param2({GetType(id1), GetType(id2)});
		auto selfID = AddVariable(type, name);
		ExportVariable(selfID, "(" + GetNameWithCast(id1, type) + "+" + GetNameWithCast(id2, type) + ")");
		return selfID;
	}

	int32_t Subtract(int32_t id1, int32_t id2, const std::string& name = "")
	{
		auto type = InferOutputTypeIn2Out1Param2({GetType(id1), GetType(id2)});
		auto selfID = AddVariable(type, name);
		ExportVariable(selfID, "(" + GetNameWithCast(id1, type) + "-" + GetNameWithCast(id2, type) + ")");
		return selfID;
	}

	int32_t Mul(int32_t id1, int32_t id2, const std::string& name = "")
	{
		auto type = InferOutputTypeIn2Out1Param2({GetType(id1), GetType(id2)});
		auto selfID = AddVariable(type, name);
		ExportVariable(selfID, "(" + GetNameWithCast(id1, type) + "*" + GetNameWithCast(id2, type) + ")");
		return selfID;
	}

	int32_t Div(int32_t id1, int32_t id2, const std::string& name = "")
	{
		auto type = InferOutputTypeIn2Out1Param2({GetType(id1), GetType(id2)});
		auto selfID = AddVariable(type, name);
		ExportVariable(selfID, "(" + GetNameWithCast(id1, type) + "/" + GetNameWithCast(id2, type) + ")");
		return selfID;
	}

	int32_t Min(int32_t id1, int32_t id2, const std::string& name = "")
	{
		auto type = InferOutputTypeIn2Out1Param2({GetType(id1), GetType(id2)});
		auto selfID = AddVariable(type, name);
		ExportVariable(selfID, "min(" + GetNameWithCast(id1, type) + "," + GetNameWithCast(id2, type) + ")");
		return selfID;
	}

	int32_t Max(int32_t id1, int32_t id2, const std::string& name = "")
	{
		auto type = InferOutputTypeIn2Out1Param2({GetType(id1), GetType(id2)});
		auto selfID = AddVariable(type, name);
		ExportVariable(selfID, "max(" + GetNameWithCast(id1, type) + "," + GetNameWithCast(id2, type) + ")");
		return selfID;
	}

	int32_t Abs(int32_t id, const std::string& name = "")
	{
		auto type = GetType(id);
		auto selfID = AddVariable(type, name);
		ExportVariable(selfID, "abs(" + GetName(id) + ")");
		return selfID;
	}

	int32_t Pow(int32_t id, int32_t base, const std::string& name = "")
	{
		auto type = GetType(id);

		auto selfID = AddVariable(type, name);
		auto masked = ComponentMask(base, {true, false, false, false});
		ExportVariable(selfID, "pow(" + GetName(id) + "," + GetNameWithCast(masked, type) + ")");
		return selfID;
	}

	int32_t Sin(int32_t id, const std::string& name = "")
	{
		auto selfID = AddVariable(variables_[id].Type, name);
		ExportVariable(selfID, "sin(" + GetName(id) + ")");
		return selfID;
	}

	int32_t Cos(int32_t id, const std::string& name = "")
	{
		auto selfID = AddVariable(variables_[id].Type, name);
		ExportVariable(selfID, "cos(" + GetName(id) + ")");
		return selfID;
	}

	int32_t Atan2(int32_t y, int32_t x, const std::string& name = "")
	{
		auto type = InferOutputTypeIn2Out1Param2({GetType(y), GetType(x)});
		auto selfID = AddVariable(type, name);
		ExportVariable(selfID, "atan2(" + GetNameWithCast(y, type) + "," + GetNameWithCast(x, type) + ")");
		return selfID;
	}

	int32_t Dot(int32_t id1, int32_t id2, const std::string& name = "")
	{
		auto selfID = AddVariable(ValueType::Float1, name);
		ExportVariable(selfID, "dot(" + GetName(id1) + "," + GetName(id2) + ")");
		return selfID;
	}

	int32_t Normalize(int32_t id, const std::string& name = "")
	{
		auto selfID = AddVariable(GetType(id), name);
		ExportVariable(selfID, "normalize(" + GetName(id) + ")");
		return selfID;
	}

	int32_t Sqrt(int32_t id, const std::string& name = "")
	{
		auto selfID = AddVariable(GetType(id), name);
		ExportVariable(selfID, "sqrt(" + GetName(id) + ")");
		return selfID;
	}

	int32_t Step(int32_t edge, int32_t value, const std::string& name = "")
	{
		auto selfID = AddVariable(ValueType::Float1, name);
		ExportVariable(selfID, "step(" + GetNameWithCast(edge, ValueType::Float1) + "," + GetNameWithCast(value, ValueType::Float1) + ")");
		return selfID;
	}

	int32_t AppendVector(int32_t id1, int32_t id2, const std::string& name = "")
	{
		auto allCount = GetElementCount(GetType(id1)) + GetElementCount(GetType(id2));
		auto type = InferOutputTypeInAppendVector({GetType(id1), GetType(id2)});

		auto selfID = AddVariable(type, name);

		str_ << exporter_->GetTypeName(type) << " " << GetName(selfID) << " = " << exporter_->GetTypeName(type) << "(";

		auto getElmName = [](int n) -> std::string {
			if (n == 0)
				return ".x";
			if (n == 1)
				return ".y";
			if (n == 2)
				return ".z";
			if (n == 3)
				return ".w";
			return "";
		};

		auto v1Count = GetElementCount(GetType(id1));
		auto v2Count = allCount - v1Count;

		for (int i = 0; i < v1Count; i++)
		{
			if (GetType(id1) == ValueType::Float1)
			{
				str_ << GetName(id1);
			}
			else
			{
				str_ << GetName(id1) << getElmName(i);
			}

			if (i < allCount - 1)
				str_ << ",";
		}

		for (int i = 0; i < v2Count; i++)
		{
			if (GetType(id2) == ValueType::Float1)
			{
				str_ << GetName(id2);
			}
			else
			{
				str_ << GetName(id2) << getElmName(i);
			}

			if (v1Count + i < allCount - 1)
				str_ << ",";
		}

		str_ << ");" << std::endl;

		return selfID;
	}

	int32_t ComponentMask(int32_t id, std::array<bool, 4> mask, const std::string& name = "")
	{
		int elmCount = 0;
		for (size_t i = 0; i < 4; i++)
		{
			if (mask[i])
			{
				elmCount++;
			}
		}

		auto type = static_cast<ValueType>(static_cast<int>(ValueType::Float1) + elmCount - 1);
		auto selfID = AddVariable(type, name);

		str_ << exporter_->GetTypeName(type) << " " << GetName(selfID) << "=" << GetNameWithCast(id, ValueType::Float4) << ".";

		if (mask[0])
			str_ << "x";

		if (mask[1])
			str_ << "y";

		if (mask[2])
			str_ << "z";

		if (mask[3])
			str_ << "w";

		str_ << ";" << std::endl;

		return selfID;
	}

	int32_t EffectScale() { return effectScaleID_; }

	int32_t CameraPosition() { return cameraPositionID_; }

	int32_t WorldPosition() { return worldPositionID_; }

	int32_t NormalPixelDir() { return pixelNormalDirID_; }

	int32_t DepthFade(int32_t fadeDistance, const std::string& name = "")
	{
		auto selfID = AddVariable(ValueType::Float1, name);

		str_ << exporter_->GetTypeName(ValueType::Float1) << " " << GetName(selfID) << "=CalcDepthFade(screenUV, meshZ, " << GetName(fadeDistance) << ");" << std::endl;

		return selfID;
	}
};

TextExporterResult TextExporter::Export(std::shared_ptr<Material> material, std::shared_ptr<Node> outputNode, std::string suffix)
{
	if (!(outputNode->OutputPins.size() != 0 || outputNode->Parameter->Type == NodeType::Output))
		return TextExporterResult();

	// Init
	compiler = std::make_shared<TextCompiler>(this);

	// Gather node
	std::vector<std::shared_ptr<Node>> nodes;
	std::unordered_set<std::shared_ptr<Node>> foundNodes;

	GatherNodes(material, outputNode, nodes, foundNodes);

	// Generate wrapper with variables
	std::reverse(nodes.begin(), nodes.end());

	// Check custom data
	int32_t customData1Count = 0;
	int32_t customData2Count = 0;

	for (auto& node : nodes)
	{
		if (node->Parameter->Type == NodeType::CustomData1)
		{
			for (int32_t i = 0; i < 4; i++)
			{
				if (node->Properties[i]->Floats[0] > 0)
				{
					customData1Count = std::max(customData1Count, i + 1);
				}
			}
		}

		if (node->Parameter->Type == NodeType::CustomData2)
		{
			for (int32_t i = 0; i < 4; i++)
			{
				if (node->Properties[i]->Floats[0] > 0)
				{
					customData2Count = std::max(customData2Count, i + 1);
				}
			}
		}
	}

	// Generate exporter node
	std::vector<std::shared_ptr<TextExporterNode>> exportedNodes;
	std::unordered_map<std::shared_ptr<Node>, std::shared_ptr<TextExporterNode>> node2exportedNode;

	std::map<uint64_t, std::shared_ptr<TextExporterTexture>> extractedTextures;
	std::map<uint64_t, std::shared_ptr<TextExporterUniform>> extractedUniforms;

	int32_t variableInd = 0;
	for (auto node : nodes)
	{
		auto teNode = std::make_shared<TextExporterNode>();
		teNode->Target = node;

		for (auto pin : node->OutputPins)
		{
			TextExporterPin tePin;
			tePin.IsConnected = material->GetConnectedPins(pin).size() > 0;

			std::unordered_set<std::shared_ptr<Pin>> visited;
			auto type = material->GetDesiredPinType(pin, visited);

			if (type == ValueType::String || type == ValueType::Texture)
			{
				// these types cannot export into shader as varibales
				tePin.Name = "unused" + std::to_string(variableInd);
				tePin.Type = type;

				if (node->Parameter->Type == NodeType::TextureObject)
				{
					auto path = node->Properties[0]->Str;

					std::shared_ptr<TextExporterTexture> extractedTexture;

					if (extractedTextures.count(node->GUID) > 0)
					{
						extractedTexture = extractedTextures[node->GUID];
					}
					else
					{
						extractedTexture = std::make_shared<TextExporterTexture>();
						extractedTexture->IsInternal = true;
						extractedTexture->DefaultPath = path;
						extractedTexture->IsParam = false;
						extractedTexture->Type = material->FindTexture(path.c_str())->Type;
						extractedTexture->GUID = node->GUID;
						extractedTextures[node->GUID] = extractedTexture;
					}

					tePin.TextureValue = extractedTexture;
				}

				if (node->Parameter->Type == NodeType::TextureObjectParameter)
				{
					auto paramName = node->GetProperty("Name")->Str;
					auto path = node->GetProperty("Texture")->Str;

					std::shared_ptr<TextExporterTexture> extractedTexture;

					if (extractedTextures.count(node->GUID) > 0)
					{
						extractedTexture = extractedTextures[node->GUID];
					}
					else
					{
						extractedTexture = std::make_shared<TextExporterTexture>();
						extractedTexture->Name = paramName;
						extractedTexture->DefaultPath = path;
						extractedTexture->IsParam = true;
						extractedTexture->Type = material->FindTexture(path.c_str())->Type;
						extractedTexture->Priority = static_cast<int32_t>(node->GetProperty("Priority")->Floats[0]);
						extractedTexture->Descriptions = node->Descriptions;
						extractedTexture->GUID = node->GUID;
						extractedTextures[node->GUID] = extractedTexture;
					}

					tePin.TextureValue = extractedTexture;
				}
			}
			else if (type == ValueType::Unknown || type == ValueType::FloatN || type == ValueType::Function)
			{
				// these types doesn't exists
				tePin.Name = "invalid" + std::to_string(variableInd);
				tePin.Type = type;
			}
			else
			{
				if (node->Parameter->Type == NodeType::Parameter1 || node->Parameter->Type == NodeType::Parameter2 ||
					node->Parameter->Type == NodeType::Parameter3 || node->Parameter->Type == NodeType::Parameter4)
				{
					auto paramName = EspcapeUserParamName(node->GetProperty("Name")->Str.c_str());
					auto values = node->GetProperty("Value")->Floats;

					std::shared_ptr<TextExporterUniform> extractedUniform;

					if (extractedUniforms.count(node->GUID) > 0)
					{
						extractedUniform = extractedUniforms[node->GUID];
					}
					else
					{
						extractedUniform = std::make_shared<TextExporterUniform>();
						extractedUniform->Name = paramName;
						extractedUniform->DefaultConstants = values;
						extractedUniform->Priority = static_cast<int32_t>(node->GetProperty("Priority")->Floats[0]);
						extractedUniform->Descriptions = node->Descriptions;
						extractedUniform->GUID = node->GUID;

						if (node->Parameter->Type == NodeType::Parameter1)
						{
							extractedUniform->Type = ValueType::Float1;
						}
						else if (node->Parameter->Type == NodeType::Parameter2)
						{
							extractedUniform->Type = ValueType::Float2;
						}
						else if (node->Parameter->Type == NodeType::Parameter3)
						{
							extractedUniform->Type = ValueType::Float3;
						}
						else if (node->Parameter->Type == NodeType::Parameter4)
						{
							extractedUniform->Type = ValueType::Float4;
						}

						extractedUniforms[node->GUID] = extractedUniform;
					}

					tePin.UniformValue = extractedUniform;
				}

				tePin.Name = "val" + std::to_string(variableInd);
				tePin.Type = type;
			}

			teNode->Outputs.push_back(tePin);
			variableInd++;
		}

		exportedNodes.push_back(teNode);
		node2exportedNode[node] = teNode;
	}

	// Assgin inputs and extract uniform and textures

	for (auto enode : exportedNodes)
	{
		auto node = enode->Target;
		for (int32_t i = 0; i < node->InputPins.size(); i++)
		{
			auto pin = node->InputPins[i];

			auto connectedPins = material->GetConnectedPins(pin);

			if (connectedPins.size() > 0)
			{
				// value from connected
				assert(connectedPins.size() <= 1);
				for (auto connectedPin : connectedPins)
				{
					auto connectedNode = connectedPin->Parent.lock();
					auto connectedExportedNode = node2exportedNode[connectedNode];

					auto outputPin = connectedExportedNode->Outputs[connectedPin->PinIndex];
					enode->Inputs.push_back(outputPin);
					break;
				}
			}
			else
			{
				std::unordered_set<std::shared_ptr<Pin>> visited;

				// value from self
				TextExporterPin tePin;
				tePin.IsConnected = false;
				tePin.Default = node->Parameter->InputPins[i]->Default;
				tePin.Type = material->GetDesiredPinType(pin, visited);

				auto path = std::string();

				if (tePin.Type == ValueType::Texture)
				{
					if (node->Parameter->Type == NodeType::SampleTexture)
					{
						path = node->Properties[0]->Str;
					}
					else
					{
						assert(0);
					}

					std::shared_ptr<TextExporterTexture> extractedTexture;

					if (extractedTextures.count(node->GUID) > 0)
					{
						extractedTexture = extractedTextures[node->GUID];
					}
					else
					{
						extractedTexture = std::make_shared<TextExporterTexture>();
						extractedTexture->IsInternal = true;
						extractedTexture->DefaultPath = path;
						extractedTexture->Type = material->FindTexture(path.c_str())->Type;
						extractedTexture->GUID = node->GUID;
						extractedTextures[node->GUID] = extractedTexture;
					}

					tePin.TextureValue = extractedTexture;
				}
				else
				{
					tePin.NumberValue = node->Parameter->InputPins[i]->DefaultValues;
				}

				enode->Inputs.push_back(tePin);
			}

			{
				auto& tePin = enode->Inputs.back();

				if (tePin.Type == ValueType::Texture)
				{
					// assign a sampler
					tePin.TextureValue->Sampler =
						static_cast<TextureSamplerType>((int)node->Properties[node->Parameter->GetPropertyIndex("Sampler")]->Floats[0]);
				}
			}
		}
	}

	// get output node
	auto outputExportedNode = node2exportedNode[outputNode];

	// Assign texture index
	std::unordered_set<std::string> usedName;

	{
		int32_t textureCount = 0;
		int id = 0;

		for (auto& extracted : extractedTextures)
		{
			extracted.second->UniformName = "efk_texture_" + std::to_string(extracted.first);

			if (!IsValidName(extracted.second->Name.c_str()) || usedName.count(extracted.second->Name) > 0)
			{
				if (extracted.second->IsInternal)
				{
					extracted.second->Name = "_InternalTexture_" + std::to_string(textureCount);
					textureCount++;
				}
				else
				{
					extracted.second->Name = extracted.second->UniformName;
				}
			}

			usedName.insert(extracted.second->Name);
			extracted.second->Index = id;
			id++;
		}
	}

	// Assign Uniform
	{
		int32_t offset = 0;
		int32_t ind = 0;
		for (auto& extracted : extractedUniforms)
		{
			extracted.second->UniformName = "efk_uniform_" + std::to_string(extracted.first);

			if (!IsValidName(extracted.second->Name.c_str()) || usedName.count(extracted.second->Name) > 0)
			{
				extracted.second->Name = extracted.second->UniformName;
			}
			usedName.insert(extracted.second->Name);

			extracted.second->Offset = offset;
			offset += sizeof(float) * 4;
			ind += 1;
		}
	}

	// for output
	TextExporterOutputOption option;
	if (outputNode->Parameter->Type == NodeType::Output)
	{
		auto worldPositionOffsetInd = outputNode->GetInputPinIndex("WorldPositionOffset");
		option.HasWorldPositionOffset = material->GetConnectedPins(outputNode->InputPins[worldPositionOffsetInd]).size() != 0;

		auto refractionInd = outputNode->GetInputPinIndex("Refraction");
		option.HasRefraction = material->GetConnectedPins(outputNode->InputPins[refractionInd]).size() != 0;
		option.ShadingModel = static_cast<int>(outputNode->Properties[0]->Floats[0]);
	}
	else
	{
		option.HasRefraction = false;
		option.ShadingModel = 1;
	}

	// Generate outputs
	std::ostringstream ret;

	// collect pixelNormalDir and export it first.
	// it is able to use pixelNormalDir for other calculating
	if (outputExportedNode->Target->Parameter->Type == NodeType::Output)
	{
		auto normalIndex = outputExportedNode->Target->GetInputPinIndex("Normal");
		if (outputExportedNode->Inputs[normalIndex].IsConnected)
		{
			std::vector<std::shared_ptr<Node>> pnNodes;
			std::unordered_set<std::shared_ptr<Node>> pnFoundNodes;

			GatherNodes(material, outputExportedNode->Target->InputPins[normalIndex], pnNodes, pnFoundNodes);

			// nodes to calculate pixelNormalDir
			std::vector<std::shared_ptr<TextExporterNode>> pnExportedNodes;
			std::vector<std::shared_ptr<TextExporterNode>> tempExportedNodes;

			for (auto wn : exportedNodes)
			{
				if (pnFoundNodes.find(wn->Target) != pnFoundNodes.end())
				{
					pnExportedNodes.push_back(wn);
				}
				else
				{
					tempExportedNodes.push_back(wn);
				}
			}

			exportedNodes = tempExportedNodes;

			// export pixelnormaldir
			for (auto wn : pnExportedNodes)
			{
				ret << ExportNode(wn);
			}

			ret << " pixelNormalDir = " << GetInputArg(ValueType::Float3, outputExportedNode->Inputs[normalIndex]) << ";" << std::endl;
			ret << GetTypeName(ValueType::Float3) << " tempPixelNormalDir = ((pixelNormalDir -" << GetTypeName(ValueType::Float3)
				<< " (0.5, 0.5, 0.5)) * 2.0);" << std::endl;

			ret << "pixelNormalDir = tempPixelNormalDir.x * worldTangent + tempPixelNormalDir.y * worldBinormal + tempPixelNormalDir.z * "
				   "worldNormal;"
				<< std::endl;
		}
	}

	for (auto wn : exportedNodes)
	{
		ret << ExportNode(wn);
	}

	ret << ExportOutputNode(material, outputExportedNode, option);

	std::ostringstream uniform_textures;

	std::vector<std::shared_ptr<TextExporterUniform>> uniforms;
	std::vector<std::shared_ptr<TextExporterTexture>> textures;

	for (auto& kv : extractedTextures)
	{
		textures.push_back(kv.second);
	}

	for (auto& kv : extractedUniforms)
	{
		uniforms.push_back(kv.second);
	}

	uniform_textures << ExportUniformAndTextures(uniforms, textures);

	TextExporterResult result;
	result.Code = MergeTemplate(ret.str(), uniform_textures.str());
	result.ShadingModel = option.ShadingModel;
	result.Uniforms = uniforms;
	result.Textures = textures;
	result.HasRefraction = option.HasRefraction;
	result.CustomData1 = customData1Count;
	result.CustomData2 = customData2Count;
	return result;
};

std::string TextExporter::GenerateTempName()
{
	std::ostringstream ret;
	ret << "temp_" << tempID;
	tempID++;
	return ret.str();
}

void TextExporter::GatherNodes(std::shared_ptr<Material> material,
							   std::shared_ptr<Node> node,
							   std::vector<std::shared_ptr<Node>>& nodes,
							   std::unordered_set<std::shared_ptr<Node>>& foundNodes)
{
	// already exists, so rearrange it
	if (foundNodes.count(node) > 0)
	{
		for (size_t i = 0; i < nodes.size(); i++)
		{
			if (node == nodes[i])
			{
				nodes.erase(nodes.begin() + i);
				break;
			}
		}
	}
	else
	{
		foundNodes.insert(node);
	}

	nodes.push_back(node);

	for (auto p : node->InputPins)
	{
		auto relatedPins = material->GetConnectedPins(p);

		for (auto relatedPin : relatedPins)
		{
			auto relatedNode = relatedPin->Parent.lock();
			GatherNodes(material, relatedNode, nodes, foundNodes);
		}
	}
}

void TextExporter::GatherNodes(std::shared_ptr<Material> material,
							   std::shared_ptr<Pin> pin,
							   std::vector<std::shared_ptr<Node>>& nodes,
							   std::unordered_set<std::shared_ptr<Node>>& foundNodes)
{
	auto relatedPins = material->GetConnectedPins(pin);

	for (auto relatedPin : relatedPins)
	{
		auto relatedNode = relatedPin->Parent.lock();
		GatherNodes(material, relatedNode, nodes, foundNodes);
	}
}

std::string TextExporter::MergeTemplate(std::string code, std::string uniform_texture)
{
	const char template_[] = R"(

RETURN

)";

	auto ret = Replace(template_, "RETURN", code);
	ret = Replace(ret.c_str(), "UNIFORM_TEXTURE", uniform_texture);

	return ret;
}

std::string TextExporter::ExportOutputNode(std::shared_ptr<Material> material,
										   std::shared_ptr<TextExporterNode> outputNode,
										   const TextExporterOutputOption& option)
{
	std::ostringstream ret;

	if (outputNode->Target->Parameter->Type == NodeType::Output)
	{
		auto worldPositionOffsetIndex = outputNode->Target->GetInputPinIndex("WorldPositionOffset");
		auto baseColorIndex = outputNode->Target->GetInputPinIndex("BaseColor");
		auto emissiveIndex = outputNode->Target->GetInputPinIndex("Emissive");
		auto refractionIndex = outputNode->Target->GetInputPinIndex("Refraction");
		auto normalIndex = outputNode->Target->GetInputPinIndex("Normal");
		auto roughnessIndex = outputNode->Target->GetInputPinIndex("Roughness");
		auto metallicIndex = outputNode->Target->GetInputPinIndex("Metallic");
		auto ambientOcclusionIndex = outputNode->Target->GetInputPinIndex("AmbientOcclusion");
		auto opacityIndex = outputNode->Target->GetInputPinIndex("Opacity");
		auto opacityMaskIndex = outputNode->Target->GetInputPinIndex("OpacityMask");

		ret << GetTypeName(ValueType::Float3) << " normalDir = " << GetInputArg(ValueType::Float3, outputNode->Inputs[normalIndex]) << ";"
			<< std::endl;

		//ret << GetTypeName(ValueType::Float3) << " tempNormalDir = ((normalDir -" << GetTypeName(ValueType::Float3)
		//	<< " (0.5, 0.5, 0.5)) * 2.0);" << std::endl;
		//
		//ret << "pixelNormalDir = tempNormalDir.x * worldTangent + tempNormalDir.y * worldBinormal + tempNormalDir.z * worldNormal;"
		//	<< std::endl;

		ret << GetTypeName(ValueType::Float3)
			<< " worldPositionOffset = " << GetInputArg(ValueType::Float3, outputNode->Inputs[worldPositionOffsetIndex]) << ";"
			<< std::endl;

		ret << GetTypeName(ValueType::Float3) << " baseColor = " << GetInputArg(ValueType::Float3, outputNode->Inputs[baseColorIndex])
			<< ";" << std::endl;

		ret << GetTypeName(ValueType::Float3) << " emissive = " << GetInputArg(ValueType::Float3, outputNode->Inputs[emissiveIndex]) << ";"
			<< std::endl;

		ret << GetTypeName(ValueType::Float1) << " metallic = " << GetInputArg(ValueType::Float1, outputNode->Inputs[metallicIndex]) << ";"
			<< std::endl;

		ret << GetTypeName(ValueType::Float1) << " roughness = " << GetInputArg(ValueType::Float1, outputNode->Inputs[roughnessIndex])
			<< ";" << std::endl;

		ret << GetTypeName(ValueType::Float1)
			<< " ambientOcclusion = " << GetInputArg(ValueType::Float1, outputNode->Inputs[ambientOcclusionIndex]) << ";" << std::endl;

		ret << GetTypeName(ValueType::Float1) << " opacity = " << GetInputArg(ValueType::Float1, outputNode->Inputs[opacityIndex]) << ";"
			<< std::endl;

		ret << GetTypeName(ValueType::Float1) << " opacityMask = " << GetInputArg(ValueType::Float1, outputNode->Inputs[opacityMaskIndex])
			<< ";" << std::endl;

		ret << GetTypeName(ValueType::Float1) << " refraction = " << GetInputArg(ValueType::Float1, outputNode->Inputs[refractionIndex])
			<< ";" << std::endl;
	}
	else
	{
		ret << GetTypeName(ValueType::Float3) << " worldPositionOffset = " << GetTypeName(ValueType::Float3) << "(0, 0, 0);" << std::endl;

		if (outputNode->Target->Parameter->Type == NodeType::TextureObject)
		{
			ret << GetTypeName(ValueType::Float4) << " emissive_temp = "
				<< "texture(" << outputNode->Outputs[0].TextureValue->UniformName << ", GetUV(" << GetUVName(0) << "));" << std::endl;
			ret << GetTypeName(ValueType::Float3) << " emissive = emissive_temp.xyz;" << std::endl;
			ret << "float opacity = emissive_temp.w;" << std::endl;

			ret << "float opacityMask = 1.0;" << std::endl;
		}
		else if (outputNode->Target->Parameter->Type == NodeType::TextureObjectParameter)
		{
			ret << GetTypeName(ValueType::Float4) << " emissive_temp = "
				<< "texture(" << outputNode->Outputs[0].TextureValue->UniformName << ", GetUV(" << GetUVName(0) << "));" << std::endl;
			ret << GetTypeName(ValueType::Float3) << " emissive = emissive_temp.xyz;" << std::endl;
			ret << "float opacity = emissive_temp.w;" << std::endl;

			ret << "float opacityMask = 1.0;" << std::endl;
		}
		else
		{
			ret << GetTypeName(ValueType::Float3)
				<< " emissive = " << ConvertType(ValueType::Float3, outputNode->Outputs[0].Type, outputNode->Outputs[0].Name) << ";"
				<< std::endl;
			ret << "float opacity = 1.0;" << std::endl;

			ret << "float opacityMask = 1.0;" << std::endl;
		}
	}

	return ret.str();
}

std::string TextExporter::ExportNode(std::shared_ptr<TextExporterNode> node)
{
	auto exportInputOrProp = [this](ValueType type_, TextExporterPin& pin_, std::shared_ptr<NodeProperty>& prop_) -> std::string {
		if (pin_.IsConnected)
		{
			return GetInputArg(type_, pin_);
		}
		return GetInputArg(pin_.Type, prop_->Floats[0]);
	};

	std::ostringstream ret;

	auto exportIn2Out2Param2 = [&, this](const char* func, const char* op) -> void {
		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "=" << func << "("
			<< exportInputOrProp(node->Outputs[0].Type, node->Inputs[0], node->Target->Properties[0]) << op
			<< exportInputOrProp(node->Outputs[0].Type, node->Inputs[1], node->Target->Properties[1]) << ");" << std::endl;
	};

	auto exportIn1Out1 = [&, this](const char* func) -> void {
		assert(node->Inputs.size() == 1);
		assert(node->Outputs.size() == 1);
		assert(node->Inputs[0].Type == node->Outputs[0].Type);
		ret << GetTypeName(node->Inputs[0].Type) << " " << node->Outputs[0].Name << "=" << func << "("
			<< GetInputArg(node->Inputs[0].Type, node->Inputs[0]) << ");" << std::endl;
	};

	// for opengl es
	auto getNum = [](float f) -> std::string {
		std::ostringstream ret;
		if (f == (int)f)
		{
			ret << f << ".0";
		}
		else
		{
			ret << f;
		}

		return ret.str();
	};

	if (node->Target->Parameter->Type == NodeType::Constant1)
	{
		ret << GetTypeName(ValueType::Float1) << " " << node->Outputs[0].Name << "=" << getNum(node->Target->Properties[0]->Floats[0])
			<< ";" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::Constant2)
	{
		ret << GetTypeName(ValueType::Float2) << " " << node->Outputs[0].Name << "=" << GetTypeName(ValueType::Float2) << "("
			<< getNum(node->Target->Properties[0]->Floats[0]) << "," << getNum(node->Target->Properties[0]->Floats[1]) << ");" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::Constant3)
	{
		auto& floats = node->Target->Properties[0]->Floats;
		ret << GetTypeName(ValueType::Float3) << " " << node->Outputs[0].Name << "=" << GetTypeName(ValueType::Float3) << "("
			<< getNum(floats[0]) << "," << getNum(floats[1]) << "," << getNum(floats[2]) << ");" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::Constant4)
	{
		auto& floats = node->Target->Properties[0]->Floats;
		ret << GetTypeName(ValueType::Float4) << " " << node->Outputs[0].Name << "=" << GetTypeName(ValueType::Float4) << "("
			<< getNum(floats[0]) << "," << getNum(floats[1]) << "," << getNum(floats[2]) << "," << getNum(floats[3]) << ");" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::Parameter1)
	{
		ret << GetTypeName(ValueType::Float1) << " " << node->Outputs[0].Name << "=" << node->Outputs[0].UniformValue->UniformName << ".x"
			<< ";" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::Parameter2)
	{
		ret << GetTypeName(ValueType::Float2) << " " << node->Outputs[0].Name << "=" << node->Outputs[0].UniformValue->UniformName << ".xy"
			<< ";" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::Parameter3)
	{
		ret << GetTypeName(ValueType::Float3) << " " << node->Outputs[0].Name << "=" << node->Outputs[0].UniformValue->UniformName << ".xyz"
			<< ";" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::Parameter4)
	{
		ret << GetTypeName(ValueType::Float4) << " " << node->Outputs[0].Name << "=" << node->Outputs[0].UniformValue->UniformName << ";"
			<< std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::Sine)
	{
		exportIn1Out1("sin");
	}

	if (node->Target->Parameter->Type == NodeType::Arctangent2)
	{
		exportIn2Out2Param2("atan2", ",");
	}

	if (node->Target->Parameter->Type == NodeType::Abs)
	{
		exportIn1Out1("abs");
	}

	if (node->Target->Parameter->Type == NodeType::Add)
	{
		exportIn2Out2Param2("", "+");
	}

	if (node->Target->Parameter->Type == NodeType::Subtract)
	{
		exportIn2Out2Param2("", "-");
	}

	if (node->Target->Parameter->Type == NodeType::Multiply)
	{
		exportIn2Out2Param2("", "*");
	}

	if (node->Target->Parameter->Type == NodeType::Divide)
	{
		exportIn2Out2Param2("", "/");
	}

	if (node->Target->Parameter->Type == NodeType::FMod)
	{
		exportIn2Out2Param2("MOD", ",");
	}

	if (node->Target->Parameter->Type == NodeType::Step)
	{
		int edgeArg = 0;
		int valueArg = 0;

		if (node->Inputs[0].IsConnected)
		{
			edgeArg = compiler->AddVariable(node->Inputs[0].Type, node->Inputs[0].Name);
		}
		else
		{
			edgeArg = compiler->AddConstant(ValueType::Float1, node->Inputs[0].NumberValue);
		}

		if (node->Inputs[1].IsConnected)
		{
			valueArg = compiler->AddVariable(node->Inputs[1].Type, node->Inputs[1].Name);
		}
		else
		{
			valueArg = compiler->AddConstant(ValueType::Float1, node->Inputs[1].NumberValue);
		}

		compiler->Step(edgeArg, valueArg, node->Outputs[0].Name);

		ret << compiler->Str();
		compiler->Clear();
	}

	if (node->Target->Parameter->Type == NodeType::Ceil)
	{
		exportIn1Out1("ceil");
	}

	if (node->Target->Parameter->Type == NodeType::Floor)
	{
		exportIn1Out1("floor");
	}

	if (node->Target->Parameter->Type == NodeType::Frac)
	{
		exportIn1Out1("FRAC");
	}

	if (node->Target->Parameter->Type == NodeType::Min)
	{
		exportIn2Out2Param2("min", ",");
	}

	if (node->Target->Parameter->Type == NodeType::Max)
	{
		exportIn2Out2Param2("max", ",");
	}

	if (node->Target->Parameter->Type == NodeType::Power)
	{
		int baseArg = 0;
		int expArg = 0;

		if (node->Inputs[0].IsConnected)
		{
			baseArg = compiler->AddVariable(node->Inputs[0].Type, node->Inputs[0].Name);
		}
		else
		{
			baseArg = compiler->AddConstant(0.0f);
		}

		if (node->Inputs[1].IsConnected)
		{
			expArg = compiler->AddVariable(node->Inputs[1].Type, node->Inputs[1].Name);
		}
		else
		{
			expArg = compiler->AddConstant(node->Target->Properties[0]->Floats[0]);
		}

		compiler->Pow(baseArg, expArg, node->Outputs[0].Name);

		ret << compiler->Str();
		compiler->Clear();
	}

	if (node->Target->Parameter->Type == NodeType::SquareRoot)
	{
		exportIn1Out1("sqrt");
	}

	if (node->Target->Parameter->Type == NodeType::Clamp)
	{
		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "= clamp("
			<< GetInputArg(node->Outputs[0].Type, node->Inputs[0]) << ","
			<< exportInputOrProp(node->Outputs[0].Type, node->Inputs[1], node->Target->Properties[0]) << ","
			<< exportInputOrProp(node->Outputs[0].Type, node->Inputs[2], node->Target->Properties[1]) << ");" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::DotProduct)
	{
		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "= dot("
			<< GetInputArg(node->Inputs[0].Type, node->Inputs[0]) << "," << GetInputArg(node->Inputs[0].Type, node->Inputs[1]) << ");"
			<< std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::CrossProduct)
	{
		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "= cross("
			<< GetInputArg(node->Inputs[0].Type, node->Inputs[0]) << "," << GetInputArg(node->Inputs[1].Type, node->Inputs[1]) << ");"
			<< std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::Normalize)
	{
		exportIn1Out1("normalize");
	}

	if (node->Target->Parameter->Type == NodeType::LinearInterpolate)
	{

		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "= LERP("
			<< exportInputOrProp(node->Outputs[0].Type, node->Inputs[0], node->Target->Properties[0]) << ","
			<< exportInputOrProp(node->Outputs[0].Type, node->Inputs[1], node->Target->Properties[1]) << ","
			<< exportInputOrProp(node->Inputs[2].Type, node->Inputs[2], node->Target->Properties[2]) << ");" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::TextureCoordinate)
	{
		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "="
			<< GetUVName(static_cast<int32_t>(node->Target->Properties[0]->Floats[0])) << ";" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::Panner)
	{
		auto index = node->Target->GetProperty("UVIndex");

		std::array<float, 2> speed_;
		speed_[0] = node->Target->Properties[0]->Floats[0];
		speed_[1] = node->Target->Properties[0]->Floats[1];

		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "="
			<< (node->Inputs[0].IsConnected ? GetInputArg(ValueType::Float2, node->Inputs[0]) : GetUVName(static_cast<int32_t>(index->Floats[0]))) << "+"
			<< (node->Inputs[2].IsConnected ? GetInputArg(ValueType::Float2, node->Inputs[2]) : GetInputArg(ValueType::Float2, speed_))
			<< "*" << GetInputArg(ValueType::Float1, node->Inputs[1]) << ";" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::ComponentMask)
	{
		auto compName = node->Outputs[0].Name + "_CompMask";

		ret << GetTypeName(ValueType::Float4) << " " << compName << "=" << GetInputArg(ValueType::Float4, node->Inputs[0]) << ";"
			<< std::endl;

		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "=" << compName << ".";

		if (node->Target->Properties[0]->Floats[0] > 0)
			ret << "x";

		if (node->Target->Properties[1]->Floats[0] > 0)
			ret << "y";

		if (node->Target->Properties[2]->Floats[0] > 0)
			ret << "z";

		if (node->Target->Properties[3]->Floats[0] > 0)
			ret << "w";

		ret << ";" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::AppendVector)
	{
		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "=" << GetTypeName(node->Outputs[0].Type) << "(";

		auto getElmName = [](int n) -> std::string {
			if (n == 0)
				return ".x";
			if (n == 1)
				return ".y";
			if (n == 2)
				return ".z";
			if (n == 3)
				return ".w";
			return "";
		};

		auto allCount = GetElementCount(node->Outputs[0].Type);
		auto v1Count = GetElementCount(node->Inputs[0].Type);
		auto v2Count = allCount - v1Count;

		for (int i = 0; i < v1Count; i++)
		{
			if (node->Inputs[0].Type == ValueType::Float1)
			{
				ret << GetInputArg(node->Inputs[0].Type, node->Inputs[0]);
			}
			else
			{
				ret << GetInputArg(node->Inputs[0].Type, node->Inputs[0]) << getElmName(i);
			}

			if (i < allCount - 1)
				ret << ",";
		}

		for (int i = 0; i < v2Count; i++)
		{
			if (node->Inputs[1].Type == ValueType::Float1)
			{
				ret << GetInputArg(node->Inputs[1].Type, node->Inputs[1]);
			}
			else
			{
				ret << GetInputArg(node->Inputs[1].Type, node->Inputs[1]) << getElmName(i);
			}

			if (v1Count + i < allCount - 1)
				ret << ",";
		}

		ret << ");" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::OneMinus)
	{
		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "=" << GetInputArg(node->Inputs[0].Type, 1.0f) << "-"
			<< GetInputArg(node->Inputs[0].Type, node->Inputs[0]) << ";" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::TextureObject)
	{
		// None
	}

	if (node->Target->Parameter->Type == NodeType::TextureObjectParameter)
	{
		// None
	}

	if (node->Target->Parameter->Type == NodeType::SampleTexture)
	{
		int32_t rgbInd = 0;
		assert(node->Target->GetOutputPinIndex("RGB") == rgbInd);

		int32_t rgbaInd = 5;
		assert(node->Target->GetOutputPinIndex("RGBA") == rgbaInd);

		assert(node->Inputs[0].TextureValue != nullptr);
		if (0 <= node->Inputs[0].TextureValue->Index)
		{
			ret << GetTypeName(node->Outputs[rgbaInd].Type) << " " << node->Outputs[rgbaInd].Name << " = $TEX_P"
				<< node->Inputs[0].TextureValue->Index << "$" << GetInputArg(ValueType::Float2, node->Inputs[1]) << "$TEX_S"
				<< node->Inputs[0].TextureValue->Index << "$;" << std::endl;
		}
		else
		{
			ret << GetTypeName(node->Outputs[rgbaInd].Type) << " " << node->Outputs[rgbaInd].Name << "=" << GetTypeName(ValueType::Float4)
				<< "(1.0,1.0,1.0,1.0);" << std::endl;
		}

		if (node->Outputs[1].IsConnected)
		{
			ret << GetTypeName(node->Outputs[1].Type) << " " << node->Outputs[1].Name << "=" << node->Outputs[rgbaInd].Name << ".x;"
				<< std::endl;
		}

		if (node->Outputs[2].IsConnected)
		{
			ret << GetTypeName(node->Outputs[2].Type) << " " << node->Outputs[2].Name << "=" << node->Outputs[rgbaInd].Name << ".y;"
				<< std::endl;
		}

		if (node->Outputs[3].IsConnected)
		{
			ret << GetTypeName(node->Outputs[3].Type) << " " << node->Outputs[3].Name << "=" << node->Outputs[rgbaInd].Name << ".z;"
				<< std::endl;
		}

		if (node->Outputs[4].IsConnected)
		{
			ret << GetTypeName(node->Outputs[4].Type) << " " << node->Outputs[4].Name << "=" << node->Outputs[rgbaInd].Name << ".w;"
				<< std::endl;
		}

		// for compatiblity and preview
		{
			ret << GetTypeName(node->Outputs[rgbInd].Type) << " " << node->Outputs[rgbInd].Name << "=" << node->Outputs[rgbaInd].Name
				<< ".xyz;" << std::endl;
		}
	}

	if (node->Target->Parameter->Type == NodeType::EffectScale)
	{
		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "=" << compiler->GetName(compiler->EffectScale()) << ";" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::Time)
	{
		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "=" << GetTimeName() << ";" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::CameraPositionWS)
	{
		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "="
			<< "cameraPosition.xyz"
			<< ";" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::WorldPosition)
	{
		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "="
			<< "worldPos"
			<< ";" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::VertexNormalWS)
	{
		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "="
			<< "worldNormal"
			<< ";" << std::endl;
	}

#ifdef _DEBUG
	if (node->Target->Parameter->Type == NodeType::VertexTangentWS)
	{
		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "="
			<< "worldTangent"
			<< ";" << std::endl;
	}
#endif

	if (node->Target->Parameter->Type == NodeType::PixelNormalWS)
	{
		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "="
			<< "pixelNormalDir"
			<< ";" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::VertexColor)
	{
		if (node->Outputs[0].IsConnected)
		{
			ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "= vcolor.xyz;" << std::endl;
		}

		if (node->Outputs[1].IsConnected)
		{
			ret << GetTypeName(node->Outputs[1].Type) << " " << node->Outputs[1].Name << "= vcolor.x;" << std::endl;
		}

		if (node->Outputs[2].IsConnected)
		{
			ret << GetTypeName(node->Outputs[2].Type) << " " << node->Outputs[2].Name << "= vcolor.y;" << std::endl;
		}

		if (node->Outputs[3].IsConnected)
		{
			ret << GetTypeName(node->Outputs[3].Type) << " " << node->Outputs[3].Name << "= vcolor.z;" << std::endl;
		}

		if (node->Outputs[4].IsConnected)
		{
			ret << GetTypeName(node->Outputs[4].Type) << " " << node->Outputs[4].Name << "= vcolor.w;" << std::endl;
		}
	}

	if (node->Target->Parameter->Type == NodeType::ObjectScale)
	{
		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "="
			<< "objectScale"
			<< ";" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::DepthFade)
	{
		int distanceArg = 0;
		int expArg = 0;

		if (node->Inputs[0].IsConnected)
		{
			distanceArg = compiler->AddVariable(node->Inputs[0].Type, node->Inputs[0].Name);
		}
		else
		{
			distanceArg = compiler->AddConstant(node->Target->Properties[0]->Floats[0]);
		}

		compiler->DepthFade(distanceArg, node->Outputs[0].Name);

		ret << compiler->Str();
		compiler->Clear();
	}

	if (node->Target->Parameter->Type == NodeType::CustomData1 || node->Target->Parameter->Type == NodeType::CustomData2)
	{
		std::string dstName;

		if (node->Target->Parameter->Type == NodeType::CustomData1)
		{
			dstName = "customData1";
		}
		else if (node->Target->Parameter->Type == NodeType::CustomData2)
		{
			dstName = "customData2";
		}

		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "=" << dstName << ".";

		if (node->Target->Properties[0]->Floats[0] > 0)
			ret << "x";

		if (node->Target->Properties[1]->Floats[0] > 0)
			ret << "y";

		if (node->Target->Properties[2]->Floats[0] > 0)
			ret << "z";

		if (node->Target->Properties[3]->Floats[0] > 0)
			ret << "w";

		ret << ";" << std::endl;
	}

	if (node->Target->Parameter->Type == NodeType::Fresnel)
	{
		int exponentArg = 0;
		int baseReflectFractionArg = 0;

		if (node->Inputs[0].IsConnected)
		{
			exponentArg = compiler->AddVariable(node->Inputs[0].Type, node->Inputs[0].Name);
		}
		else
		{
			exponentArg = compiler->AddConstant(node->Target->Properties[0]->Floats[0]);
		}

		if (node->Inputs[1].IsConnected)
		{
			baseReflectFractionArg = compiler->AddVariable(node->Inputs[1].Type, node->Inputs[1].Name);
		}
		else
		{
			baseReflectFractionArg = compiler->AddConstant(node->Target->Properties[1]->Floats[0]);
		}

		auto dotArg = compiler->Dot(compiler->Normalize(compiler->Subtract(compiler->CameraPosition(), compiler->WorldPosition())),
									compiler->NormalPixelDir());
		auto maxminusabsArg =
			compiler->Abs(compiler->Subtract(compiler->AddConstant(1.0f), compiler->Max(compiler->AddConstant(0.0f), dotArg)));
		auto powArg = compiler->Pow(maxminusabsArg, exponentArg);
		compiler->Add(compiler->Mul(powArg, compiler->Subtract(compiler->AddConstant(1.0f), baseReflectFractionArg)),
					  baseReflectFractionArg,
					  node->Outputs[0].Name);
		ret << compiler->Str();
		compiler->Clear();
	}

	if (node->Target->Parameter->Type == NodeType::Rotator)
	{
		auto angle = GenerateTempName();
		auto center = GenerateTempName();
		auto uv = GenerateTempName();

		ret << GetTypeName(ValueType::Float2) << " " << uv << " = "
			<< (node->Inputs[0].IsConnected ? GetInputArg(ValueType::Float2, node->Inputs[0]) : GetUVName(0)) << ";" << std::endl;

		ret << GetTypeName(ValueType::Float2) << " " << center << " = "
			<< (node->Inputs[1].IsConnected ? GetInputArg(ValueType::Float2, node->Inputs[1])
											: GetInputArg(ValueType::Float2, {0.5f, 0.5f}))
			<< ";" << std::endl;

		ret << GetTypeName(ValueType::Float1) << " " << angle << " = "
			<< (node->Inputs[2].IsConnected ? GetInputArg(ValueType::Float1, node->Inputs[2]) : GetInputArg(ValueType::Float1, 0.0f)) << ";"
			<< std::endl;

		auto centerArg = compiler->AddVariable(ValueType::Float2, center);
		auto speedArg = compiler->AddConstant(3.141592f * 2.0f);
		auto uvArg = compiler->AddVariable(ValueType::Float2, uv);
		auto angleArg = compiler->AddVariable(ValueType::Float1, angle);
		auto sinArg = compiler->Sin(compiler->Mul(speedArg, angleArg));
		auto cosArg = compiler->Cos(compiler->Mul(speedArg, angleArg));
		auto matUArg = compiler->AppendVector(cosArg, compiler->Subtract(compiler->AddConstant(0.0f), sinArg));
		auto matLArg = compiler->AppendVector(sinArg, cosArg);
		auto resultUArg = compiler->Dot(matUArg, compiler->Subtract(uvArg, centerArg));
		auto resultLArg = compiler->Dot(matLArg, compiler->Subtract(uvArg, centerArg));
		auto matResultArg = compiler->AppendVector(resultUArg, resultLArg);
		auto sumArg = compiler->Add(matResultArg, centerArg, node->Outputs[0].Name);

		ret << compiler->Str();

		compiler->Clear();
	}

	if (node->Target->Parameter->Type == NodeType::PolarCoords)
	{
		auto biasedUV = GenerateTempName();
		auto biasedUV2 = GenerateTempName();
		auto atanFrac = GenerateTempName();
		auto sqrtUV = GenerateTempName();
		auto polar = GenerateTempName();

		ret << GetTypeName(ValueType::Float2) << " " << biasedUV << " = " << GetUVName(0) << " * 2.0 - 1.0;" << std::endl;
		ret << GetTypeName(ValueType::Float2) << " " << biasedUV2 << " = " << biasedUV << " * " << biasedUV << ";" << std::endl;
		ret << GetTypeName(ValueType::Float1) << " " << atanFrac << " = "
			<< "FRAC(atan2(" << biasedUV << ".y, " << biasedUV << ".x) / 6.283);" << std::endl;
		ret << GetTypeName(ValueType::Float1) << " " << sqrtUV << " = sqrt(" << biasedUV2 << ".x + " << biasedUV2 << ".y);" << std::endl;
		ret << GetTypeName(node->Outputs[0].Type) << " " << polar << " = " << GetTypeName(node->Outputs[0].Type) << "(" << atanFrac << ","
			<< sqrtUV << ");" << std::endl;

		auto last = compiler->AddVariable(ValueType::Float2, polar);

		// Tile
		{
			auto tile = node->Inputs[0].IsConnected ? compiler->AddVariable(ValueType::Float2, node->Inputs[0].Name)
													: compiler->AddConstant(ValueType::Float2, node->Target->Properties[0]->Floats);
			last = compiler->Mul(last, tile);
		}

		// Offset
		{
			auto offset = node->Inputs[1].IsConnected ? compiler->AddVariable(ValueType::Float2, node->Inputs[1].Name)
													  : compiler->AddConstant(ValueType::Float2, node->Target->Properties[1]->Floats);
			last = compiler->Add(last, offset);
		}

		// Pitch(V)
		{
			auto exp = node->Inputs[2].IsConnected ? compiler->AddVariable(ValueType::Float1, node->Inputs[2].Name)
												   : compiler->AddConstant(ValueType::Float1, node->Target->Properties[2]->Floats);
			auto h = compiler->ComponentMask(last, {true, false, false, false});
			auto v = compiler->ComponentMask(last, {false, true, false, false});
			v = compiler->Pow(v, exp);
			last = compiler->AppendVector(h, v);
		}

		ret << compiler->Str();

		compiler->Clear();

		ret << GetTypeName(node->Outputs[0].Type) << " " << node->Outputs[0].Name << "=" << compiler->GetName(last) << ";" << std::endl;
	}

	return ret.str();
}

std::string TextExporter::ExportUniformAndTextures(const std::vector<std::shared_ptr<TextExporterUniform>>& uniformNodes,
												   const std::vector<std::shared_ptr<TextExporterTexture>>& textureNodes)
{

	std::ostringstream ret;

	// for (auto node : uniformNodes)
	//{
	//	ret << "uniform " << GetTypeName(node->Type) << " " << node->Name << ";" << std::endl;
	//}
	//
	// for (auto node : textureNodes)
	//{
	//	ret << "uniform sampler2D " << node->Name << ";" << std::endl;
	//}

	return ret.str();
}

std::string TextExporter::GetInputArg(const ValueType& pinType, TextExporterPin& pin)
{
	if (pin.IsConnected)
	{
		if (pin.Type == pinType)
			return pin.Name;

		return ConvertType(pinType, pin.Type, pin.Name);
	}
	else
	{
		// for opengl es
		auto getNum = [&pin](int i) -> std::string {
			auto f = pin.NumberValue[i];

			std::ostringstream ret;
			if (f == (int)f)
			{
				ret << f << ".0";
			}
			else
			{
				ret << f;
			}

			return ret.str();
		};

		if (pin.Default == DefaultType::UV)
			return GetUVName(0);

		if (pin.Default == DefaultType::Time)
			return GetTimeName();

		std::ostringstream ret;

		if (pin.Type == ValueType::Float1)
		{
			ret << GetTypeName(pin.Type) << "(" << getNum(0) << ")";
		}
		if (pin.Type == ValueType::Float2)
		{
			ret << GetTypeName(pin.Type) << "(" << getNum(0) << "," << getNum(1) << ")";
		}
		if (pin.Type == ValueType::Float3)
		{
			ret << GetTypeName(pin.Type) << "(" << getNum(0) << "," << getNum(1) << "," << getNum(2) << ")";
		}
		if (pin.Type == ValueType::Float4)
		{
			ret << GetTypeName(pin.Type) << "(" << getNum(0) << "," << getNum(1) << "," << getNum(2) << "," << getNum(3) << ")";
		}

		if (pin.Type == pinType)
			return ret.str();

		return ConvertType(pinType, pin.Type, ret.str());
	}
}

std::string TextExporter::GetInputArg(const ValueType& pinType, float value)
{
	std::ostringstream ret;

	// for opengl es
	auto getNum = [](float f) -> std::string {
		std::ostringstream ret;
		if (f == (int)f)
		{
			ret << f << ".0";
		}
		else
		{
			ret << f;
		}

		return ret.str();
	};

	auto valueStr = getNum(value);

	if (pinType == ValueType::Float1)
	{
		ret << GetTypeName(pinType) << "(" << valueStr << ")";
	}
	if (pinType == ValueType::Float2)
	{
		ret << GetTypeName(pinType) << "(" << valueStr << "," << valueStr << ")";
	}
	if (pinType == ValueType::Float3)
	{
		ret << GetTypeName(pinType) << "(" << valueStr << "," << valueStr << "," << valueStr << ")";
	}
	if (pinType == ValueType::Float4)
	{
		ret << GetTypeName(pinType) << "(" << valueStr << "," << valueStr << "," << valueStr << "," << valueStr << ")";
	}

	return ret.str();
}

std::string TextExporter::GetInputArg(const ValueType& pinType, std::array<float, 2> value)
{
	// for opengl es
	auto getNum = [](float f) -> std::string {
		std::ostringstream ret;
		if (f == (int)f)
		{
			ret << f << ".0";
		}
		else
		{
			ret << f;
		}

		return ret.str();
	};

	std::ostringstream ret;

	if (pinType == ValueType::Float1)
	{
		ret << GetTypeName(pinType) << "(" << getNum(value[0]) << ")";
	}
	if (pinType == ValueType::Float2)
	{
		ret << GetTypeName(pinType) << "(" << getNum(value[0]) << "," << getNum(value[1]) << ")";
	}
	if (pinType == ValueType::Float3)
	{
		ret << GetTypeName(pinType) << "(" << getNum(value[0]) << ".x ," << getNum(value[1]) << ".y ,"
			<< "0.0"
			<< ")";
	}
	if (pinType == ValueType::Float4)
	{
		ret << GetTypeName(pinType) << "(" << getNum(value[0]) << ".x ," << getNum(value[1]) << ".y ,"
			<< "0.0, 1.0"
			<< ")";
	}

	return ret.str();
}

std::string TextExporter::GetTypeName(ValueType type) const
{
	if (type == ValueType::Float1)
		return "$F1$";
	if (type == ValueType::Float2)
		return "$F2$";
	if (type == ValueType::Float3)
		return "$F3$";
	if (type == ValueType::Float4)
		return "$F4$";
	return "";
}

std::string TextExporter::GetUVName(int32_t ind) const
{
	if (ind == 0)
	{
		return "$UV$1";
	}
	return "$UV$2";
}

std::string TextExporter::GetTimeName() const { return "$TIME$"; }

std::string TextExporter::ConvertType(ValueType dst, ValueType src, const std::string& name) const
{
	if (dst == src)
		return name;

	if (dst == ValueType::Float1)
	{
		return name + ".x";
	}
	else if (dst == ValueType::Float2)
	{
		if (src == ValueType::Float1)
		{
			return GetTypeName(ValueType::Float2) + "(" + name + "," + name + ")";
		}
		return GetTypeName(ValueType::Float2) + "(" + name + ".x," + name + ".y)";
	}
	else if (dst == ValueType::Float3)
	{
		if (src == ValueType::Float1)
		{
			return GetTypeName(ValueType::Float3) + "(" + name + "," + name + "," + name + ")";
		}
		else if (src == ValueType::Float2)
		{
			return GetTypeName(ValueType::Float3) + "(" + name + ".x, " + name + ".y, 0.0)";
		}
		return GetTypeName(ValueType::Float3) + "(" + name + ".x," + name + ".y," + name + ".z)";
	}
	else if (dst == ValueType::Float4)
	{
		if (src == ValueType::Float1)
		{
			return GetTypeName(ValueType::Float4) + "(" + name + "," + name + "," + name + "," + name + ")";
		}
		else if (src == ValueType::Float2)
		{
			return GetTypeName(ValueType::Float4) + "(" + name + ".x," + name + ".y, 0.0, 1.0)";
		}
		else if (src == ValueType::Float3)
		{
			return GetTypeName(ValueType::Float4) + "(" + name + ".x," + name + ".y," + name + ".z, 1.0)";
		}
	}
	return "";
}

} // namespace EffekseerMaterial