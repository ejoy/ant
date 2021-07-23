#include "EffekseerRendererBGFX.MaterialLoader.h"
#include "EffekseerRendererBGFX.ModelRenderer.h"
#include "EffekseerRendererBGFX.Shader.h"

#include <iostream>
#include <fstream>
#include "../EffekseerRendererCommon/PathUtils.h"
#include "../EffekseerMaterialCompiler/EffekseerMaterialCompilerBGFX.h"
#include "Effekseer/Material/Effekseer.CompiledMaterial.h"

#undef min

void load_fx(const std::string& vspath, const std::string& fspath, bgfx_program_handle_t& program,
	std::unordered_map<std::string, bgfx_uniform_handle_t>& uniforms);

namespace EffekseerRendererBGFX
{
	static const int GL_InstanceCount = 10;

	::Effekseer::MaterialRef MaterialLoader::LoadAcutually(::Effekseer::MaterialFile& materialFile, ::Effekseer::CompiledMaterialBinary* binary)
	{
		//	auto deviceType = graphicsDevice_->GetDeviceType();

		auto instancing = false; // deviceType == OpenGLDeviceType::OpenGL3 || deviceType == OpenGLDeviceType::OpenGLES3;

		auto material = ::Effekseer::MakeRefPtr<::Effekseer::Material>();
		material->IsSimpleVertex = materialFile.GetIsSimpleVertex();
		material->IsRefractionRequired = materialFile.GetHasRefraction();

		std::array<Effekseer::MaterialShaderType, 2> shaderTypes;
		std::array<Effekseer::MaterialShaderType, 2> shaderTypesModel;

		shaderTypes[0] = Effekseer::MaterialShaderType::Standard;
		shaderTypes[1] = Effekseer::MaterialShaderType::Refraction;
		shaderTypesModel[0] = Effekseer::MaterialShaderType::Model;
		shaderTypesModel[1] = Effekseer::MaterialShaderType::RefractionModel;
		int32_t shaderTypeCount = 1;

		if (materialFile.GetHasRefraction()) {
			shaderTypeCount = 2;
		}
		auto dir = currentPath_.substr(0, currentPath_.find("/tools/") + 1) + "packages/resources/shaders/effekseer/";
		auto startPos = currentPath_.rfind('/');
		auto fileName = currentPath_.substr(startPos + 1, currentPath_.rfind('.') - startPos - 1);

		auto create_shader = [this, &dir, &fileName](::Effekseer::CompiledMaterialBinary* binary,
			Effekseer::MaterialShaderType type, bool isModel) {
				auto vsFileName = "vs_" + fileName;
				if (isModel) {
					vsFileName += "_model";
				}
				auto vsFullName = dir + vsFileName + ".sc";
				std::ofstream vsFile(vsFullName);
				if (vsFile.is_open()) {
					vsFile << binary->GetVertexShaderData(type), binary->GetVertexShaderSize(type);
					vsFile.close();
				}
				auto fsFileName = "fs_" + fileName;
				if (isModel) {
					fsFileName += "_model";
				}
				auto fsFullName = dir + fsFileName + ".sc";
				std::ofstream fsFile(fsFullName);
				if (fsFile.is_open()) {
					fsFile << binary->GetPixelShaderData(type), binary->GetPixelShaderSize(type);
					fsFile.close();
				}
				
				bgfx_program_handle_t program;
				std::unordered_map<std::string, bgfx_uniform_handle_t> uniforms;
				load_fx(vsFullName, fsFullName, program, uniforms);
				return Shader::Create(renderer_, program, std::move(uniforms));
		};

		for (int32_t st = 0; st < shaderTypeCount; st++)
		{
			auto parameterGenerator = EffekseerRenderer::MaterialShaderParameterGenerator(materialFile, false, st, 1);

			auto shader = create_shader(binary, shaderTypes[st], false);

			shader->AddVertexConstantLayout(CONSTANT_TYPE_MATRIX44, shader->GetUniformId("uMatCamera"), parameterGenerator.VertexCameraMatrixOffset);

			shader->AddVertexConstantLayout(CONSTANT_TYPE_MATRIX44, shader->GetUniformId("uMatProjection"), parameterGenerator.VertexProjectionMatrixOffset);

			shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("mUVInversed"), parameterGenerator.VertexInversedFlagOffset);

			shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("vs_predefined_uniform"), parameterGenerator.VertexPredefinedOffset);

			shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("vs_cameraPosition"), parameterGenerator.VertexCameraPositionOffset);

			for (int32_t ui = 0; ui < materialFile.GetUniformCount(); ui++)
			{
				auto name = std::string("vs_") + materialFile.GetUniformName(ui);
				shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId(name.c_str()),
					parameterGenerator.VertexUserUniformOffset + sizeof(float) * 4 * ui);
			}

			shader->SetVertexConstantBufferSize(parameterGenerator.VertexShaderUniformBufferSize);

			shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("mUVInversedBack"), parameterGenerator.PixelInversedFlagOffset);

			shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fs_predefined_uniform"), parameterGenerator.PixelPredefinedOffset);

			shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fs_cameraPosition"), parameterGenerator.PixelCameraPositionOffset);

			shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("reconstructionParam1"), parameterGenerator.PixelReconstructionParam1Offset);

			shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("reconstructionParam2"), parameterGenerator.PixelReconstructionParam2Offset);

			// shiding model
			if (materialFile.GetShadingModel() == ::Effekseer::ShadingModelType::Lit)
			{
				shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("lightDirection"), parameterGenerator.PixelLightDirectionOffset);
				shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("lightColor"), parameterGenerator.PixelLightColorOffset);
				shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("lightAmbientColor"), parameterGenerator.PixelLightAmbientColorOffset);
			}
			else if (materialFile.GetShadingModel() == ::Effekseer::ShadingModelType::Unlit)
			{
			}

			if (materialFile.GetHasRefraction() && st == 1)
			{
				shader->AddPixelConstantLayout(CONSTANT_TYPE_MATRIX44, shader->GetUniformId("cameraMat"), parameterGenerator.PixelCameraMatrixOffset);
			}

			for (int32_t ui = 0; ui < materialFile.GetUniformCount(); ui++)
			{
				auto name = std::string("fs_") + materialFile.GetUniformName(ui);
				shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId(name.c_str()),
					parameterGenerator.PixelUserUniformOffset + sizeof(float) * 4 * ui);
			}

			shader->SetPixelConstantBufferSize(parameterGenerator.PixelShaderUniformBufferSize);

			int32_t lastIndex = -1;
			for (int32_t ti = 0; ti < materialFile.GetTextureCount(); ti++)
			{
				shader->SetTextureSlot(materialFile.GetTextureIndex(ti), shader->GetUniformId(materialFile.GetTextureName(ti)));
				lastIndex = Effekseer::Max(lastIndex, materialFile.GetTextureIndex(ti));
			}

			lastIndex += 1;
			shader->SetTextureSlot(lastIndex, shader->GetUniformId("efk_background"));

			lastIndex += 1;
			shader->SetTextureSlot(lastIndex, shader->GetUniformId("efk_depth"));

			material->TextureCount = materialFile.GetTextureCount();
			material->UniformCount = materialFile.GetUniformCount();

			if (st == 0)
			{
				material->UserPtr = shader;
			}
			else
			{
				material->RefractionUserPtr = shader;
			}
		}

		for (int32_t st = 0; st < shaderTypeCount; st++)
		{
			auto parameterGenerator = EffekseerRenderer::MaterialShaderParameterGenerator(materialFile, true, st, instancing ? GL_InstanceCount : 1);

			auto shader = create_shader(binary, shaderTypesModel[st], true);

			shader->AddVertexConstantLayout(CONSTANT_TYPE_MATRIX44, shader->GetUniformId("ProjectionMatrix"), parameterGenerator.VertexProjectionMatrixOffset);

			if (instancing)
			{
				shader->AddVertexConstantLayout(CONSTANT_TYPE_MATRIX44, shader->GetUniformId("ModelMatrix"), parameterGenerator.VertexModelMatrixOffset, GL_InstanceCount);

				shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("UVOffset"), parameterGenerator.VertexModelUVOffset, GL_InstanceCount);

				shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("ModelColor"), parameterGenerator.VertexModelColorOffset, GL_InstanceCount);
			}
			else
			{
				shader->AddVertexConstantLayout(CONSTANT_TYPE_MATRIX44, shader->GetUniformId("ModelMatrix"), parameterGenerator.VertexModelMatrixOffset);

				shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("UVOffset"), parameterGenerator.VertexModelUVOffset);

				shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("ModelColor"), parameterGenerator.VertexModelColorOffset);
			}

			shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("mUVInversed"), parameterGenerator.VertexInversedFlagOffset);

			shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("vs_predefined_uniform"), parameterGenerator.VertexPredefinedOffset);

			shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("vs_cameraPosition"), parameterGenerator.VertexCameraPositionOffset);

			shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("reconstructionParam1"), parameterGenerator.PixelReconstructionParam1Offset);

			shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("reconstructionParam2"), parameterGenerator.PixelReconstructionParam2Offset);

			if (instancing)
			{
				if (materialFile.GetCustomData1Count() > 0)
				{
					shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("customData1s"), parameterGenerator.VertexModelCustomData1Offset, GL_InstanceCount);
				}

				if (materialFile.GetCustomData2Count() > 0)
				{
					shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("customData2s"), parameterGenerator.VertexModelCustomData2Offset, GL_InstanceCount);
				}
			}
			else
			{
				if (materialFile.GetCustomData1Count() > 0)
				{
					shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("customData1"), parameterGenerator.VertexModelCustomData1Offset);
				}

				if (materialFile.GetCustomData2Count() > 0)
				{
					shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("customData2"), parameterGenerator.VertexModelCustomData2Offset);
				}
			}

			for (int32_t ui = 0; ui < materialFile.GetUniformCount(); ui++)
			{
				auto name = std::string("vs_") + materialFile.GetUniformName(ui);
				shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4,
					shader->GetUniformId(name.c_str()),
					parameterGenerator.VertexUserUniformOffset + sizeof(float) * 4 * ui);
			}

			shader->SetVertexConstantBufferSize(parameterGenerator.VertexShaderUniformBufferSize);

			shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("mUVInversedBack"), parameterGenerator.PixelInversedFlagOffset);

			shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fs_predefined_uniform"), parameterGenerator.PixelPredefinedOffset);

			shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fs_cameraPosition"), parameterGenerator.PixelCameraPositionOffset);

			// shiding model
			if (materialFile.GetShadingModel() == ::Effekseer::ShadingModelType::Lit)
			{
				shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("lightDirection"), parameterGenerator.PixelLightDirectionOffset);
				shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("lightColor"), parameterGenerator.PixelLightColorOffset);
				shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("lightAmbientColor"), parameterGenerator.PixelLightAmbientColorOffset);
			}
			else if (materialFile.GetShadingModel() == ::Effekseer::ShadingModelType::Unlit)
			{
			}

			if (materialFile.GetHasRefraction() && st == 1)
			{
				shader->AddPixelConstantLayout(
					CONSTANT_TYPE_MATRIX44, shader->GetUniformId("cameraMat"), parameterGenerator.PixelCameraMatrixOffset);
			}

			for (int32_t ui = 0; ui < materialFile.GetUniformCount(); ui++)
			{
				auto name = std::string("fs_") + materialFile.GetUniformName(ui);
				shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4,
					shader->GetUniformId(name.c_str()),
					parameterGenerator.PixelUserUniformOffset + sizeof(float) * 4 * ui);
			}

			shader->SetPixelConstantBufferSize(parameterGenerator.PixelShaderUniformBufferSize);

			int32_t lastIndex = -1;
			for (int32_t ti = 0; ti < materialFile.GetTextureCount(); ti++)
			{
				shader->SetTextureSlot(materialFile.GetTextureIndex(ti), shader->GetUniformId(materialFile.GetTextureName(ti)));
				lastIndex = Effekseer::Max(lastIndex, materialFile.GetTextureIndex(ti));
			}

			lastIndex += 1;
			shader->SetTextureSlot(lastIndex, shader->GetUniformId("efk_background"));

			lastIndex += 1;
			shader->SetTextureSlot(lastIndex, shader->GetUniformId("efk_depth"));

			if (st == 0)
			{
				material->ModelUserPtr = shader;
			}
			else
			{
				material->RefractionModelUserPtr = shader;
			}
		}

		material->CustomData1 = materialFile.GetCustomData1Count();
		material->CustomData2 = materialFile.GetCustomData2Count();
		material->TextureCount = std::min(materialFile.GetTextureCount(), Effekseer::UserTextureSlotMax);
		material->UniformCount = materialFile.GetUniformCount();
		material->ShadingModel = materialFile.GetShadingModel();

		for (int32_t i = 0; i < material->TextureCount; i++)
		{
			material->TextureWrapTypes.at(i) = materialFile.GetTextureWrap(i);
		}

		return material;
	}

	MaterialLoader::MaterialLoader(Renderer* renderer, ::Effekseer::FileInterface* fileInterface, bool canLoadFromCache)
		: renderer_(renderer)
		, fileInterface_(fileInterface)
		, canLoadFromCache_(canLoadFromCache)
	{
		if (!fileInterface) {
			fileInterface_ = &defaultFileInterface_;
		}
	}

	MaterialLoader ::~MaterialLoader()
	{
	}

	::Effekseer::MaterialRef MaterialLoader::Load(const char16_t* path)
	{
		// code file
		if (canLoadFromCache_)
		{
			auto binaryPath = std::u16string(path) + u"d";
			std::unique_ptr<Effekseer::FileReader> reader(fileInterface_->TryOpenRead(binaryPath.c_str()));

			if (reader.get() != nullptr)
			{
				size_t size = reader->GetLength();
				std::vector<char> data;
				data.resize(size);
				reader->Read(data.data(), size);

				auto material = Load(data.data(), (int32_t)size, ::Effekseer::MaterialFileType::Compiled);

				if (material != nullptr)
				{
					return material;
				}
			}
		}

		// code file
		{
			auto ant_path = get_ant_file_path(w2u(path));
			currentPath_ = ant_path;
			std::unique_ptr<::Effekseer::FileReader> reader(fileInterface_->OpenRead(u2w(ant_path).data()));
			if (reader.get() == nullptr)
			{
				return nullptr;
			}

			size_t size = reader->GetLength();
			std::unique_ptr<uint8_t[]> data(new uint8_t[size]);
			reader->Read(data.get(), size);

			auto material = Load(data.get(), (int32_t)size, ::Effekseer::MaterialFileType::Code);

			return material;
		}

		return nullptr;
	}

	::Effekseer::MaterialRef MaterialLoader::Load(const void* data, int32_t size, Effekseer::MaterialFileType fileType)
	{
		if (fileType == Effekseer::MaterialFileType::Compiled)
		{
			auto compiled = Effekseer::CompiledMaterial();
			if (!compiled.Load(static_cast<const uint8_t*>(data), size))
			{
				return nullptr;
			}

			if (!compiled.GetHasValue(::Effekseer::CompiledMaterialPlatformType::OpenGL))
			{
				return nullptr;
			}

			// compiled
			Effekseer::MaterialFile materialFile;
			if (!materialFile.Load((const uint8_t*)compiled.GetOriginalData().data(), static_cast<int32_t>(compiled.GetOriginalData().size())))
			{
				std::cout << "Error : Invalid material is loaded." << std::endl;
				return nullptr;
			}

			auto binary = compiled.GetBinary(::Effekseer::CompiledMaterialPlatformType::OpenGL);

			return LoadAcutually(materialFile, binary);
		}
		else
		{
			Effekseer::MaterialFile materialFile;
			if (!materialFile.Load((const uint8_t*)data, size))
			{
				std::cout << "Error : Invalid material is loaded." << std::endl;
				return nullptr;
			}

			auto compiler = ::Effekseer::CreateUniqueReference(new Effekseer::MaterialCompilerBGFX());
			auto binary = ::Effekseer::CreateUniqueReference(compiler->Compile(&materialFile));

			return LoadAcutually(materialFile, binary.get());
		}
	}

	void MaterialLoader::Unload(::Effekseer::MaterialRef data)
	{
		if (data == nullptr)
			return;
		auto shader = reinterpret_cast<Shader*>(data->UserPtr);
		auto modelShader = reinterpret_cast<Shader*>(data->ModelUserPtr);
		auto refractionShader = reinterpret_cast<Shader*>(data->RefractionUserPtr);
		auto refractionModelShader = reinterpret_cast<Shader*>(data->RefractionModelUserPtr);

		ES_SAFE_DELETE(shader);
		ES_SAFE_DELETE(modelShader);
		ES_SAFE_DELETE(refractionShader);
		ES_SAFE_DELETE(refractionModelShader);

		data->UserPtr = nullptr;
		data->ModelUserPtr = nullptr;
		data->RefractionUserPtr = nullptr;
		data->RefractionModelUserPtr = nullptr;
	}

} // namespace EffekseerRendererGL