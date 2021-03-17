
#pragma once

#include "efkMat.Base.h"
#include "efkMat.Models.h"

namespace EffekseerMaterial
{

/**
	@brief	required uniforms
*/
struct TextExporterUniform
{
	ValueType Type;
	std::string Name;
	std::string UniformName;
	std::array<float, 4> DefaultConstants;
	int32_t Offset;
	int32_t Priority = 1;
	uint64_t GUID = 0;
	std::vector<std::shared_ptr<NodeDescription>> Descriptions;
};

/**
	@brief	required texture
*/
struct TextExporterTexture
{
	std::string Name;
	std::string UniformName;
	bool IsInternal = false;
	int32_t Index;
	std::string DefaultPath;
	bool IsParam = false;
	TextureValueType Type = TextureValueType::Color;
	TextureSamplerType Sampler = TextureSamplerType::Unknown;
	int32_t Priority = 1;
	uint64_t GUID = 0;
	std::vector<std::shared_ptr<NodeDescription>> Descriptions;
};

struct TextExporterPin
{
	std::string Name;
	ValueType Type;

	//! if pin is output, always true (should be improved)
	bool IsConnected = false;
	DefaultType Default;

	std::array<float, 4> NumberValue;
	std::shared_ptr<TextExporterUniform> UniformValue;
	std::shared_ptr<TextExporterTexture> TextureValue;
};

struct TextExporterNode
{
	std::vector<TextExporterPin> Inputs;
	std::shared_ptr<Node> Target;
	std::vector<TextExporterPin> Outputs;
};

/**
	@brief	A codes and textures in the material
*/
struct TextExporterResult
{
	std::string Code;
	int32_t ShadingModel = 0;
	bool HasRefraction = false;
	int32_t CustomData1 = 0;
	int32_t CustomData2 = 0;
	std::vector<std::shared_ptr<TextExporterUniform>> Uniforms;
	std::vector<std::shared_ptr<TextExporterTexture>> Textures;
};

class TextExporterOutputOption
{
public:
	int ShadingModel = 0;
	bool HasRefraction = false;
	bool HasDepth = false;
	bool HasUV2 = false;
	bool HasWorldPositionOffset = false;
};

class TextCompiler;

class TextExporter
{
	friend class TextCompiler;

public:
	TextExporter() = default;
	virtual ~TextExporter() = default;

	TextExporterResult Export(std::shared_ptr<Material> material, std::shared_ptr<Node> outputNode, std::string suffix = "");

protected:
	int32_t tempID = 0;
	std::shared_ptr<TextCompiler> compiler;

	std::string GenerateTempName();

	void GatherNodes(std::shared_ptr<Material> material,
					 std::shared_ptr<Node> node,
					 std::vector<std::shared_ptr<Node>>& nodes,
					 std::unordered_set<std::shared_ptr<Node>>& foundNodes);

	void GatherNodes(std::shared_ptr<Material> material,
					 std::shared_ptr<Pin> pin,
					 std::vector<std::shared_ptr<Node>>& nodes,
					 std::unordered_set<std::shared_ptr<Node>>& foundNodes);

	virtual std::string MergeTemplate(std::string code, std::string uniform_texture);

	virtual std::string ExportOutputNode(std::shared_ptr<Material> material,
										 std::shared_ptr<TextExporterNode> outputNode,
										 const TextExporterOutputOption& option);

	virtual std::string ExportNode(std::shared_ptr<TextExporterNode> node);

	virtual std::string ExportUniformAndTextures(const std::vector<std::shared_ptr<TextExporterUniform>>& uniformNodes,
												 const std::vector<std::shared_ptr<TextExporterTexture>>& textureNodes);

	virtual std::string GetInputArg(const ValueType& pinType, TextExporterPin& pin);

	virtual std::string GetInputArg(const ValueType& pinType, float value);

	virtual std::string GetInputArg(const ValueType& pinType, std::array<float, 2> value);

	virtual std::string GetTypeName(ValueType type) const;

	virtual std::string GetUVName(int32_t ind) const;

	virtual std::string GetTimeName() const;

	virtual std::string ConvertType(ValueType dst, ValueType src, const std::string& name) const;
};

} // namespace EffekseerMaterial