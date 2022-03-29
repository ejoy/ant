#include "EffekseerMaterialCompilerBGFX.h"

#include <iostream>

#include "BGFX.h"

namespace Effekseer
{

static const int InstanceCount = 10;

class CompiledMaterialBinaryBGFX : public CompiledMaterialBinary, public ReferenceObject
{
private:
	std::array<std::vector<uint8_t>, static_cast<int32_t>(MaterialShaderType::Max)> vertexShaders_;

	std::array<std::vector<uint8_t>, static_cast<int32_t>(MaterialShaderType::Max)> pixelShaders_;

public:
	CompiledMaterialBinaryBGFX()
	{
	}

	virtual ~CompiledMaterialBinaryBGFX()
	{
	}

	void SetVertexShaderData(MaterialShaderType type, const std::vector<uint8_t>& data)
	{
		vertexShaders_.at(static_cast<int>(type)) = data;
	}

	void SetPixelShaderData(MaterialShaderType type, const std::vector<uint8_t>& data)
	{
		pixelShaders_.at(static_cast<int>(type)) = data;
	}

	const uint8_t* GetVertexShaderData(MaterialShaderType type) const override
	{
		return vertexShaders_.at(static_cast<int>(type)).data();
	}

	int32_t GetVertexShaderSize(MaterialShaderType type) const override
	{
		return static_cast<int32_t>(vertexShaders_.at(static_cast<int>(type)).size());
	}

	const uint8_t* GetPixelShaderData(MaterialShaderType type) const override
	{
		return pixelShaders_.at(static_cast<int>(type)).data();
	}

	int32_t GetPixelShaderSize(MaterialShaderType type) const override
	{
		return static_cast<int32_t>(pixelShaders_.at(static_cast<int>(type)).size());
	}

	int AddRef() override
	{
		return ReferenceObject::AddRef();
	}

	int Release() override
	{
		return ReferenceObject::Release();
	}

	int GetRef() override
	{
		return ReferenceObject::GetRef();
	}
};

CompiledMaterialBinary* MaterialCompilerBGFX::Compile(MaterialFile* materialFile, int32_t maximumTextureCount)
{
	auto binary = new CompiledMaterialBinaryBGFX();

	auto convertToVector = [](const std::string& str) -> std::vector<uint8_t> {
		std::vector<uint8_t> ret;
		ret.resize(str.size() + 1);
		memcpy(ret.data(), str.data(), str.size());
		ret[str.size()] = 0;
		return ret;
	};

	auto saveBinary = [&materialFile, &binary, &convertToVector, &maximumTextureCount](MaterialShaderType type) {
		BGFX::ShaderGenerator generator;
		auto shader = generator.GenerateShader(materialFile, type, maximumTextureCount, false, false, false, false, 0, false, false, InstanceCount);
		binary->SetVertexShaderData(type, convertToVector(shader.CodeVS));
		binary->SetPixelShaderData(type, convertToVector(shader.CodePS));
	};

	if (materialFile->GetHasRefraction())
	{
		saveBinary(MaterialShaderType::Refraction);
		saveBinary(MaterialShaderType::RefractionModel);
	}

	saveBinary(MaterialShaderType::Standard);
	saveBinary(MaterialShaderType::Model);

	return binary;
}

CompiledMaterialBinary* MaterialCompilerBGFX::Compile(MaterialFile* materialFile)
{
	return Compile(materialFile, Effekseer::UserTextureSlotMax);
}

} // namespace Effekseer

#ifdef __SHARED_OBJECT__

extern "C"
{
#ifdef _WIN32
#define EFK_EXPORT __declspec(dllexport)
#else
#define EFK_EXPORT
#endif

	EFK_EXPORT Effekseer::MaterialCompiler* EFK_STDCALL CreateCompiler()
	{
		return new Effekseer::MaterialCompilerBGFX();
	}
}
#endif