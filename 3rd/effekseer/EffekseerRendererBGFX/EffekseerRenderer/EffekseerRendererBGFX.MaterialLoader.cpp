#include "EffekseerRendererBGFX.MaterialLoader.h"
#include "EffekseerRendererBGFX.ModelRenderer.h"
#include "EffekseerRendererBGFX.Shader.h"

#include <iostream>

//#include "../EffekseerMaterialCompiler/OpenGL/EffekseerMaterialCompilerGL.h"
#include "Effekseer/Material/Effekseer.CompiledMaterial.h"

#undef min

namespace EffekseerRendererBGFX
{

static const int GL_InstanceCount = 10;

::Effekseer::MaterialRef MaterialLoader::LoadAcutually(::Effekseer::MaterialFile& materialFile, ::Effekseer::CompiledMaterialBinary* binary)
{
	//auto deviceType = graphicsDevice_->GetDeviceType();

// 	auto instancing = true/*deviceType == OpenGLDeviceType::OpenGL3 || deviceType == OpenGLDeviceType::OpenGLES3*/;
// 
// 	auto material = ::Effekseer::MakeRefPtr<::Effekseer::Material>();
// 	material->IsSimpleVertex = materialFile.GetIsSimpleVertex();
// 	material->IsRefractionRequired = materialFile.GetHasRefraction();
// 
// 	std::array<Effekseer::MaterialShaderType, 2> shaderTypes;
// 	std::array<Effekseer::MaterialShaderType, 2> shaderTypesModel;
// 
// 	shaderTypes[0] = Effekseer::MaterialShaderType::Standard;
// 	shaderTypes[1] = Effekseer::MaterialShaderType::Refraction;
// 	shaderTypesModel[0] = Effekseer::MaterialShaderType::Model;
// 	shaderTypesModel[1] = Effekseer::MaterialShaderType::RefractionModel;
// 	int32_t shaderTypeCount = 1;
// 
// 	if (materialFile.GetHasRefraction())
// 	{
// 		shaderTypeCount = 2;
// 	}
// 
// 	for (int32_t st = 0; st < shaderTypeCount; st++)
// 	{
// 		auto parameterGenerator = EffekseerRenderer::MaterialShaderParameterGenerator(materialFile, false, st, 1);
// 
// 		ShaderCodeView vs((const char*)binary->GetVertexShaderData(shaderTypes[st]));
// 		ShaderCodeView ps((const char*)binary->GetPixelShaderData(shaderTypes[st]));
// 
// 		auto shader = Shader::Create("",""/*graphicsDevice_, &vs, 1, &ps, 1, "CustomMaterial", true, true*/);
// 
// 		if (shader == nullptr)
// 		{
// 			std::cout << "Vertex shader error" << std::endl;
// 			std::cout << (const char*)binary->GetVertexShaderData(shaderTypesModel[st]) << std::endl;
// 
// 			std::cout << "Pixel shader error" << std::endl;
// 			std::cout << (const char*)binary->GetPixelShaderData(shaderTypesModel[st]) << std::endl;
// 
// 			return nullptr;
// 		}
// 
// 		if (material->IsSimpleVertex)
// 		{
// 			//EffekseerRendererBGFX::ShaderAttribInfo sprite_attribs[3] = {
// 			//	{"atPosition", GL_FLOAT, 3, 0, false}, {"atColor", GL_UNSIGNED_BYTE, 4, 12, true}, {"atTexCoord", GL_FLOAT, 2, 16, false}};
// 			//shader->GetAttribIdList(3, sprite_attribs);
// 		}
// 		else
// 		{
// 			//EffekseerRendererBGFX::ShaderAttribInfo sprite_attribs[8] = {
// 			//	{"atPosition", GL_FLOAT, 3, 0, false},
// 			//	{"atColor", GL_UNSIGNED_BYTE, 4, 12, true},
// 			//	{"atNormal", GL_UNSIGNED_BYTE, 4, 16, true},
// 			//	{"atTangent", GL_UNSIGNED_BYTE, 4, 20, true},
// 			//	{"atTexCoord", GL_FLOAT, 2, 24, false},
// 			//	{"atTexCoord2", GL_FLOAT, 2, 32, false},
// 			//	{"", GL_FLOAT, 0, 0, false},
// 			//	{"", GL_FLOAT, 0, 0, false},
// 			//};
// 
// 			//int32_t offset = 40;
// 			//int count = 6;
// 			//const char* customData1Name = "atCustomData1";
// 			//const char* customData2Name = "atCustomData2";
// 
// 			//if (materialFile.GetCustomData1Count() > 0)
// 			//{
// 			//	sprite_attribs[count].name = customData1Name;
// 			//	sprite_attribs[count].count = materialFile.GetCustomData1Count();
// 			//	sprite_attribs[count].offset = offset;
// 			//	count++;
// 			//	offset += sizeof(float) * materialFile.GetCustomData1Count();
// 			//}
// 
// 			//if (materialFile.GetCustomData2Count() > 0)
// 			//{
// 			//	sprite_attribs[count].name = customData2Name;
// 			//	sprite_attribs[count].count = materialFile.GetCustomData2Count();
// 			//	sprite_attribs[count].offset = offset;
// 			//	count++;
// 			//	offset += sizeof(float) * materialFile.GetCustomData2Count();
// 			//}
// 
// 			//shader->GetAttribIdList(count, sprite_attribs);
// 		}
// 
// 		shader->AddVertexConstantLayout(
// 			CONSTANT_TYPE_MATRIX44, BGFX(create_uniform)("uMatCamera", bgfx::UniformType::Mat4)/*shader->GetUniformId("uMatCamera")*/, parameterGenerator.VertexCameraMatrixOffset);
// 
// 		shader->AddVertexConstantLayout(
// 			CONSTANT_TYPE_MATRIX44, BGFX(create_uniform)("uMatProjection", bgfx::UniformType::Mat4)/*shader->GetUniformId("uMatProjection")*/, parameterGenerator.VertexProjectionMatrixOffset);
// 
// 		shader->AddVertexConstantLayout(
// 			CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("mUVInversed", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("mUVInversed")*/, parameterGenerator.VertexInversedFlagOffset);
// 
// 		shader->AddVertexConstantLayout(
// 			CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("predefined_uniform", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("predefined_uniform")*/, parameterGenerator.VertexPredefinedOffset);
// 
// 		shader->AddVertexConstantLayout(
// 			CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("cameraPosition", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("cameraPosition")*/, parameterGenerator.VertexCameraPositionOffset);
// 
// 		for (int32_t ui = 0; ui < materialFile.GetUniformCount(); ui++)
// 		{
// 			shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4,
// 				BGFX(create_uniform)(materialFile.GetUniformName(ui), BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId(materialFile.GetUniformName(ui))*/,
// 											parameterGenerator.VertexUserUniformOffset + sizeof(float) * 4 * ui);
// 		}
// 
// 		shader->SetVertexConstantBufferSize(parameterGenerator.VertexShaderUniformBufferSize);
// 
// 		shader->AddPixelConstantLayout(
// 			CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("mUVInversedBack", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("mUVInversedBack")*/, parameterGenerator.PixelInversedFlagOffset);
// 
// 		shader->AddPixelConstantLayout(
// 			CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("predefined_uniform", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("predefined_uniform")*/, parameterGenerator.PixelPredefinedOffset);
// 
// 		shader->AddPixelConstantLayout(
// 			CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("cameraPosition", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("cameraPosition")*/, parameterGenerator.PixelCameraPositionOffset);
// 
// 		shader->AddPixelConstantLayout(
// 			CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("reconstructionParam1", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("reconstructionParam1")*/, parameterGenerator.PixelReconstructionParam1Offset);
// 
// 		shader->AddPixelConstantLayout(
// 			CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("reconstructionParam2", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("reconstructionParam2")*/, parameterGenerator.PixelReconstructionParam2Offset);
// 
// 		// shiding model
// 		if (materialFile.GetShadingModel() == ::Effekseer::ShadingModelType::Lit)
// 		{
// 			shader->AddPixelConstantLayout(
// 				CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("lightDirection", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("lightDirection")*/, parameterGenerator.PixelLightDirectionOffset);
// 			shader->AddPixelConstantLayout(
// 				CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("lightColor", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("lightColor")*/, parameterGenerator.PixelLightColorOffset);
// 			shader->AddPixelConstantLayout(
// 				CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("lightAmbientColor", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("lightAmbientColor")*/, parameterGenerator.PixelLightAmbientColorOffset);
// 		}
// 		else if (materialFile.GetShadingModel() == ::Effekseer::ShadingModelType::Unlit)
// 		{
// 		}
// 
// 		if (materialFile.GetHasRefraction() && st == 1)
// 		{
// 			shader->AddPixelConstantLayout(
// 				CONSTANT_TYPE_MATRIX44, BGFX(create_uniform)("cameraMat", bgfx::UniformType::Mat4)/*shader->GetUniformId("cameraMat")*/, parameterGenerator.PixelCameraMatrixOffset);
// 		}
// 
// 		for (int32_t ui = 0; ui < materialFile.GetUniformCount(); ui++)
// 		{
// 			shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4,
// 				BGFX(create_uniform)(materialFile.GetUniformName(ui), BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId(materialFile.GetUniformName(ui))*/,
// 										   parameterGenerator.PixelUserUniformOffset + sizeof(float) * 4 * ui);
// 		}
// 
// 		shader->SetPixelConstantBufferSize(parameterGenerator.PixelShaderUniformBufferSize);
// 
// 		int32_t lastIndex = -1;
// 		for (int32_t ti = 0; ti < materialFile.GetTextureCount(); ti++)
// 		{
// 			shader->SetTextureSlot(materialFile.GetTextureIndex(ti), BGFX(create_uniform)(materialFile.GetTextureName(ti), bgfx::UniformType::Sampler)/*shader->GetUniformId(materialFile.GetTextureName(ti))*/);
// 			lastIndex = Effekseer::Max(lastIndex, materialFile.GetTextureIndex(ti));
// 		}
// 
// 		lastIndex += 1;
// 		shader->SetTextureSlot(lastIndex, BGFX(create_uniform)("efk_background", bgfx::UniformType::Sampler)/*shader->GetUniformId("efk_background")*/);
// 
// 		lastIndex += 1;
// 		shader->SetTextureSlot(lastIndex, BGFX(create_uniform)("efk_depth", bgfx::UniformType::Sampler)/*shader->GetUniformId("efk_depth")*/);
// 
// 		material->TextureCount = materialFile.GetTextureCount();
// 		material->UniformCount = materialFile.GetUniformCount();
// 
// 		if (st == 0)
// 		{
// 			material->UserPtr = shader;
// 		}
// 		else
// 		{
// 			material->RefractionUserPtr = shader;
// 		}
// 	}
// 
// 	for (int32_t st = 0; st < shaderTypeCount; st++)
// 	{
// 		auto parameterGenerator = EffekseerRenderer::MaterialShaderParameterGenerator(materialFile, true, st, instancing ? GL_InstanceCount : 1);
// 
// 		ShaderCodeView vs((const char*)binary->GetVertexShaderData(shaderTypesModel[st]));
// 		ShaderCodeView ps((const char*)binary->GetPixelShaderData(shaderTypesModel[st]));
// 
// 		auto shader = Shader::Create("",""/*graphicsDevice_, &vs, 1, &ps, 1, "CustomMaterial", true*/);
// 
// 		if (shader == nullptr)
// 		{
// 			std::cout << "Vertex shader error" << std::endl;
// 			std::cout << (const char*)binary->GetVertexShaderData(shaderTypesModel[st]) << std::endl;
// 
// 			std::cout << "Pixel shader error" << std::endl;
// 			std::cout << (const char*)binary->GetPixelShaderData(shaderTypesModel[st]) << std::endl;
// 
// 			return nullptr;
// 		}
// 
// 		//const int32_t NumAttribs = 6;
// 		//static ShaderAttribInfo g_model_attribs[NumAttribs] = {
// 		//	{"a_Position", GL_FLOAT, 3, 0, false},
// 		//	{"a_Normal", GL_FLOAT, 3, 12, false},
// 		//	{"a_Binormal", GL_FLOAT, 3, 24, false},
// 		//	{"a_Tangent", GL_FLOAT, 3, 36, false},
// 		//	{"a_TexCoord", GL_FLOAT, 2, 48, false},
// 		//	{"a_Color", GL_UNSIGNED_BYTE, 4, 56, true},
// 		//};
// 
// 		//shader->GetAttribIdList(NumAttribs, g_model_attribs);
// 
// 		shader->AddVertexConstantLayout(
// 			CONSTANT_TYPE_MATRIX44, BGFX(create_uniform)("ProjectionMatrix", bgfx::UniformType::Mat4)/*shader->GetUniformId("ProjectionMatrix")*/, parameterGenerator.VertexProjectionMatrixOffset);
// 
// 		if (instancing)
// 		{
// 			shader->AddVertexConstantLayout(
// 				CONSTANT_TYPE_MATRIX44, BGFX(create_uniform)("ModelMatrix", bgfx::UniformType::Mat4)/*shader->GetUniformId("ModelMatrix")*/, parameterGenerator.VertexModelMatrixOffset, GL_InstanceCount);
// 
// 			shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("UVOffset", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("UVOffset")*/, parameterGenerator.VertexModelUVOffset, GL_InstanceCount);
// 
// 			shader->AddVertexConstantLayout(
// 				CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("ModelColor", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("ModelColor")*/, parameterGenerator.VertexModelColorOffset, GL_InstanceCount);
// 		}
// 		else
// 		{
// 			shader->AddVertexConstantLayout(
// 				CONSTANT_TYPE_MATRIX44, BGFX(create_uniform)("ModelMatrix", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("ModelMatrix")*/, parameterGenerator.VertexModelMatrixOffset);
// 
// 			shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("UVOffset", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("UVOffset")*/, parameterGenerator.VertexModelUVOffset);
// 
// 			shader->AddVertexConstantLayout(
// 				CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("ModelColor", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("ModelColor")*/, parameterGenerator.VertexModelColorOffset);
// 		}
// 
// 		shader->AddVertexConstantLayout(
// 			CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("mUVInversed", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("mUVInversed")*/, parameterGenerator.VertexInversedFlagOffset);
// 
// 		shader->AddVertexConstantLayout(
// 			CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("predefined_uniform", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("predefined_uniform")*/, parameterGenerator.VertexPredefinedOffset);
// 
// 		shader->AddVertexConstantLayout(
// 			CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("cameraPosition", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("cameraPosition")*/, parameterGenerator.VertexCameraPositionOffset);
// 
// 		shader->AddPixelConstantLayout(
// 			CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("reconstructionParam1", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("reconstructionParam1")*/, parameterGenerator.PixelReconstructionParam1Offset);
// 
// 		shader->AddPixelConstantLayout(
// 			CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("reconstructionParam2", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("reconstructionParam2")*/, parameterGenerator.PixelReconstructionParam2Offset);
// 
// 		if (instancing)
// 		{
// 			if (materialFile.GetCustomData1Count() > 0)
// 			{
// 				shader->AddVertexConstantLayout(
// 					CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("customData1s", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("customData1s")*/, parameterGenerator.VertexModelCustomData1Offset, GL_InstanceCount);
// 			}
// 
// 			if (materialFile.GetCustomData2Count() > 0)
// 			{
// 				shader->AddVertexConstantLayout(
// 					CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("customData2s", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("customData2s")*/, parameterGenerator.VertexModelCustomData2Offset, GL_InstanceCount);
// 			}
// 		}
// 		else
// 		{
// 			if (materialFile.GetCustomData1Count() > 0)
// 			{
// 				shader->AddVertexConstantLayout(
// 					CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("customData1", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("customData1")*/, parameterGenerator.VertexModelCustomData1Offset);
// 			}
// 
// 			if (materialFile.GetCustomData2Count() > 0)
// 			{
// 				shader->AddVertexConstantLayout(
// 					CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("customData2", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("customData2")*/, parameterGenerator.VertexModelCustomData2Offset);
// 			}
// 		}
// 
// 		for (int32_t ui = 0; ui < materialFile.GetUniformCount(); ui++)
// 		{
// 			shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4,
// 				BGFX(create_uniform)(materialFile.GetUniformName(ui), BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId(materialFile.GetUniformName(ui))*/,
// 											parameterGenerator.VertexUserUniformOffset + sizeof(float) * 4 * ui);
// 		}
// 
// 		shader->SetVertexConstantBufferSize(parameterGenerator.VertexShaderUniformBufferSize);
// 
// 		shader->AddPixelConstantLayout(
// 			CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("mUVInversedBack", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("mUVInversedBack")*/, parameterGenerator.PixelInversedFlagOffset);
// 
// 		shader->AddPixelConstantLayout(
// 			CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("predefined_uniform", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("predefined_uniform")*/, parameterGenerator.PixelPredefinedOffset);
// 
// 		shader->AddPixelConstantLayout(
// 			CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("cameraPosition", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("cameraPosition")*/, parameterGenerator.PixelCameraPositionOffset);
// 
// 		// shiding model
// 		if (materialFile.GetShadingModel() == ::Effekseer::ShadingModelType::Lit)
// 		{
// 			shader->AddPixelConstantLayout(
// 				CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("lightDirection", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("lightDirection")*/, parameterGenerator.PixelLightDirectionOffset);
// 			shader->AddPixelConstantLayout(
// 				CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("lightColor", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("lightColor")*/, parameterGenerator.PixelLightColorOffset);
// 			shader->AddPixelConstantLayout(
// 				CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("lightAmbientColor", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("lightAmbientColor")*/, parameterGenerator.PixelLightAmbientColorOffset);
// 		}
// 		else if (materialFile.GetShadingModel() == ::Effekseer::ShadingModelType::Unlit)
// 		{
// 		}
// 
// 		if (materialFile.GetHasRefraction() && st == 1)
// 		{
// 			shader->AddPixelConstantLayout(
// 				CONSTANT_TYPE_MATRIX44, BGFX(create_uniform)("cameraMat", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("cameraMat")*/, parameterGenerator.PixelCameraMatrixOffset);
// 		}
// 
// 		for (int32_t ui = 0; ui < materialFile.GetUniformCount(); ui++)
// 		{
// 			shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4,
// 				BGFX(create_uniform)(materialFile.GetUniformName(ui), BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId(materialFile.GetUniformName(ui))*/,
// 										   parameterGenerator.PixelUserUniformOffset + sizeof(float) * 4 * ui);
// 		}
// 
// 		shader->SetPixelConstantBufferSize(parameterGenerator.PixelShaderUniformBufferSize);
// 
// 		int32_t lastIndex = -1;
// 		for (int32_t ti = 0; ti < materialFile.GetTextureCount(); ti++)
// 		{
// 			shader->SetTextureSlot(materialFile.GetTextureIndex(ti), BGFX(create_uniform)(materialFile.GetTextureName(ti), bgfx::UniformType::Sampler)/*shader->GetUniformId(materialFile.GetTextureName(ti))*/);
// 			lastIndex = Effekseer::Max(lastIndex, materialFile.GetTextureIndex(ti));
// 		}
// 
// 		lastIndex += 1;
// 		shader->SetTextureSlot(lastIndex, BGFX(create_uniform)("efk_background", bgfx::UniformType::Sampler)/*shader->GetUniformId("efk_background")*/);
// 
// 		lastIndex += 1;
// 		shader->SetTextureSlot(lastIndex, BGFX(create_uniform)("efk_depth", bgfx::UniformType::Sampler)/*shader->GetUniformId("efk_depth")*/);
// 
// 		if (st == 0)
// 		{
// 			material->ModelUserPtr = shader;
// 		}
// 		else
// 		{
// 			material->RefractionModelUserPtr = shader;
// 		}
// 	}
// 
// 	material->CustomData1 = materialFile.GetCustomData1Count();
// 	material->CustomData2 = materialFile.GetCustomData2Count();
// 	material->TextureCount = std::min(materialFile.GetTextureCount(), Effekseer::UserTextureSlotMax);
// 	material->UniformCount = materialFile.GetUniformCount();
// 	material->ShadingModel = materialFile.GetShadingModel();
// 
// 	for (int32_t i = 0; i < material->TextureCount; i++)
// 	{
// 		material->TextureWrapTypes.at(i) = materialFile.GetTextureWrap(i);
// 	}
// 	
// 	return material;
	return nullptr;
}

MaterialLoader::MaterialLoader(Backend::GraphicsDeviceRef graphicsDevice, ::Effekseer::FileInterface* fileInterface, bool canLoadFromCache)
	: fileInterface_(fileInterface)
	, canLoadFromCache_(canLoadFromCache)
{
	if (fileInterface == nullptr)
	{
		fileInterface_ = &defaultFileInterface_;
	}

	graphicsDevice_ = graphicsDevice;
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
		std::unique_ptr<Effekseer::FileReader> reader(fileInterface_->OpenRead(path));

		if (reader.get() != nullptr)
		{
			size_t size = reader->GetLength();
			std::vector<char> data;
			data.resize(size);
			reader->Read(data.data(), size);

			auto material = Load(data.data(), (int32_t)size, ::Effekseer::MaterialFileType::Code);

			return material;
		}
	}

	return nullptr;
}

::Effekseer::MaterialRef MaterialLoader::Load(const void* data, int32_t size, Effekseer::MaterialFileType fileType)
{
	//if (fileType == Effekseer::MaterialFileType::Compiled)
	//{
	//	auto compiled = Effekseer::CompiledMaterial();
	//	if (!compiled.Load(static_cast<const uint8_t*>(data), size))
	//	{
	//		return nullptr;
	//	}

	//	if (!compiled.GetHasValue(::Effekseer::CompiledMaterialPlatformType::OpenGL))
	//	{
	//		return nullptr;
	//	}

	//	// compiled
	//	Effekseer::MaterialFile materialFile;
	//	materialFile.Load((const uint8_t*)compiled.GetOriginalData().data(), static_cast<int32_t>(compiled.GetOriginalData().size()));
	//	auto binary = compiled.GetBinary(::Effekseer::CompiledMaterialPlatformType::OpenGL);

	//	return LoadAcutually(materialFile, binary);
	//}
	//else
	//{
	//	Effekseer::MaterialFile materialFile;
	//	if (!materialFile.Load((const uint8_t*)data, size))
	//	{
	//		std::cout << "Error : Invalid material is loaded." << std::endl;
	//	}
	//	auto compiler = ::Effekseer::CreateUniqueReference(new Effekseer::MaterialCompilerGL());
	//	auto binary = ::Effekseer::CreateUniqueReference(compiler->Compile(&materialFile));

	//	return LoadAcutually(materialFile, binary.get());
	//}
	return nullptr;
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

} // namespace EffekseerRendererBGFX
