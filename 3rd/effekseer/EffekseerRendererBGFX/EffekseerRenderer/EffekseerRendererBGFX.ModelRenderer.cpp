#include "EffekseerRendererBGFX.RenderState.h"
#include "EffekseerRendererBGFX.RendererImplemented.h"

#include "EffekseerRendererBGFX.IndexBuffer.h"
#include "EffekseerRendererBGFX.ModelRenderer.h"
#include "EffekseerRendererBGFX.Shader.h"
#include "EffekseerRendererBGFX.VertexBuffer.h"
#include <string>

//#include "ShaderHeader/ad_model_distortion_ps.h"
//#include "ShaderHeader/ad_model_distortion_vs.h"
//#include "ShaderHeader/ad_model_lit_ps.h"
//#include "ShaderHeader/ad_model_lit_vs.h"
//#include "ShaderHeader/ad_model_unlit_ps.h"
//#include "ShaderHeader/ad_model_unlit_vs.h"
//
//#include "ShaderHeader/model_distortion_ps.h"
//#include "ShaderHeader/model_distortion_vs.h"
//#include "ShaderHeader/model_lit_ps.h"
//#include "ShaderHeader/model_lit_vs.h"
//#include "ShaderHeader/model_unlit_ps.h"
//#include "ShaderHeader/model_unlit_vs.h"

namespace EffekseerRendererBGFX
{

static const int InstanceCount = 10;

std::vector<bgfx_context> ModelRenderer::s_bgfx_model_context_;
bgfx_vertex_layout_t* ModelRenderer::model_vertex_layout_ = nullptr;

static std::string Replace(std::string target, std::string from_, std::string to_)
{
	std::string::size_type Pos(target.find(from_));

	while (Pos != std::string::npos)
	{
		target.replace(Pos, from_.length(), to_);
		Pos = target.find(from_, Pos + to_.length());
	}

	return target;
}

template <int N>
void ModelRenderer::InitRenderer()
{
	auto applyPSAdvancedRendererParameterTexture = [](Shader* shader, int32_t offset) -> void {
		shader->SetTextureSlot(0 + offset, shader->GetUniformId("s_sampler_alphaTex"));
		shader->SetTextureSlot(1 + offset, shader->GetUniformId("s_sampler_uvDistortionTex"));
		shader->SetTextureSlot(2 + offset, shader->GetUniformId("s_sampler_blendTex"));
		shader->SetTextureSlot(3 + offset, shader->GetUniformId("s_sampler_blendAlphaTex"));
		shader->SetTextureSlot(4 + offset, shader->GetUniformId("s_sampler_blendUVDistortionTex"));
	};

// 	shader_ad_lit_->SetVertexConstantBufferSize(sizeof(::EffekseerRenderer::ModelRendererAdvancedVertexConstantBuffer<N>));
// 	shader_ad_unlit_->SetVertexConstantBufferSize(sizeof(::EffekseerRenderer::ModelRendererAdvancedVertexConstantBuffer<N>));
// 	shader_ad_distortion_->SetVertexConstantBufferSize(sizeof(::EffekseerRenderer::ModelRendererAdvancedVertexConstantBuffer<N>));
// 	shader_ad_lit_->SetPixelConstantBufferSize(sizeof(::EffekseerRenderer::PixelConstantBuffer));
// 	shader_ad_unlit_->SetPixelConstantBufferSize(sizeof(::EffekseerRenderer::PixelConstantBuffer));
// 	shader_ad_distortion_->SetPixelConstantBufferSize(sizeof(::EffekseerRenderer::PixelConstantBufferDistortion));

//	shader_lit_->SetVertexConstantBufferSize(sizeof(::EffekseerRenderer::ModelRendererVertexConstantBuffer<N>));
	shader_unlit_->SetVertexConstantBufferSize(sizeof(::EffekseerRenderer::ModelRendererVertexConstantBuffer<N>));
//	shader_distortion_->SetVertexConstantBufferSize(sizeof(::EffekseerRenderer::ModelRendererVertexConstantBuffer<N>));
//	shader_lit_->SetPixelConstantBufferSize(sizeof(::EffekseerRenderer::PixelConstantBuffer));
	shader_unlit_->SetPixelConstantBufferSize(sizeof(::EffekseerRenderer::PixelConstantBuffer));
//	shader_distortion_->SetPixelConstantBufferSize(sizeof(::EffekseerRenderer::PixelConstantBufferDistortion));

// 	for (auto& shader : {shader_ad_lit_, shader_lit_})
// 	{
// 		shader->SetTextureSlot(0, shader->GetUniformId("s_sampler_colorTex"));
// 		shader->SetTextureSlot(1, shader->GetUniformId("Sampler_sampler_normalTex"));
// 	}
// 	applyPSAdvancedRendererParameterTexture(shader_ad_lit_, 2);
// 	shader_lit_->SetTextureSlot(2, shader_lit_->GetUniformId("s_sampler_depthTex"));
// 	shader_ad_lit_->SetTextureSlot(7, shader_ad_lit_->GetUniformId("s_sampler_depthTex"));

	for (auto& shader : {/*shader_ad_unlit_, */shader_unlit_})
	{
		shader->SetTextureSlot(0, shader->GetUniformId("s_sampler_colorTex"));
	}
//	applyPSAdvancedRendererParameterTexture(shader_ad_unlit_, 1);
	shader_unlit_->SetTextureSlot(1, shader_unlit_->GetUniformId("s_sampler_depthTex"));
//	shader_ad_unlit_->SetTextureSlot(6, shader_ad_unlit_->GetUniformId("s_sampler_depthTex"));

// 	for (auto& shader : {shader_ad_distortion_, shader_distortion_})
// 	{
// 		shader->SetTextureSlot(0, shader->GetUniformId("s_sampler_colorTex"));
// 		shader->SetTextureSlot(1, shader->GetUniformId("Sampler_sampler_backTex"));
// 	}
// 	applyPSAdvancedRendererParameterTexture(shader_ad_distortion_, 2);
// 	shader_distortion_->SetTextureSlot(2, shader_distortion_->GetUniformId("s_sampler_depthTex"));
// 	shader_ad_distortion_->SetTextureSlot(7, shader_ad_distortion_->GetUniformId("s_sampler_depthTex"));

	Shader* shaders[4];
	shaders[0] = shader_ad_lit_;
	shaders[1] = shader_ad_unlit_;
	shaders[2] = shader_lit_;
	shaders[3] = shader_unlit_;

	for (int32_t i = 0; i < 4; i++) {
		if (i < 3) continue;

		auto isAd = i < 2;

		int vsOffset = 0;
		shaders[i]->AddVertexConstantLayout(CONSTANT_TYPE_MATRIX44, shaders[i]->GetUniformId("u_cameraProj"), vsOffset);
		vsOffset += sizeof(Effekseer::Matrix44);
		if (VertexType == EffekseerRenderer::ModelRendererVertexType::Instancing) {
			shaders[i]->AddVertexConstantLayout(CONSTANT_TYPE_MATRIX44, shaders[i]->GetUniformId("u_Model_Inst"), vsOffset, N);
		} else {
			shaders[i]->AddVertexConstantLayout(CONSTANT_TYPE_MATRIX44, shaders[i]->GetUniformId("u_Model"), vsOffset, N);
		}
		vsOffset += sizeof(Effekseer::Matrix44) * N;
		shaders[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders[i]->GetUniformId("u_fUV"), vsOffset, N);
		vsOffset += sizeof(float[4]) * N;
		if (isAd) {
			shaders[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders[i]->GetUniformId("u_fAlphaUV"), vsOffset, N);
			vsOffset += sizeof(float[4]) * N;
			shaders[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders[i]->GetUniformId("u_fUVDistortionUV"), vsOffset, N);
			vsOffset += sizeof(float[4]) * N;
			shaders[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders[i]->GetUniformId("u_fBlendUV"), vsOffset, N);
			vsOffset += sizeof(float[4]) * N;
			shaders[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders[i]->GetUniformId("u_fBlendAlphaUV"), vsOffset, N);
			vsOffset += sizeof(float[4]) * N;
			shaders[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders[i]->GetUniformId("u_fBlendUVDistortionUV"), vsOffset, N);
			vsOffset += sizeof(float[4]) * N;
			shaders[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders[i]->GetUniformId("u_fFlipbookParameter"), vsOffset);
			vsOffset += sizeof(float[4]) * 1;
			shaders[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders[i]->GetUniformId("u_fFlipbookIndexAndNextRate"), vsOffset, N);
			vsOffset += sizeof(float[4]) * N;
			shaders[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders[i]->GetUniformId("u_fModelAlphaThreshold"), vsOffset, N);
			vsOffset += sizeof(float[4]) * N;
		}
		shaders[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders[i]->GetUniformId("u_fModelColor"), vsOffset, N);
		vsOffset += sizeof(float[4]) * N;
		shaders[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders[i]->GetUniformId("u_fLightDirection"), vsOffset);
		vsOffset += sizeof(float[4]) * 1;
		shaders[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders[i]->GetUniformId("u_fLightColor"), vsOffset);
		vsOffset += sizeof(float[4]) * 1;
		shaders[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders[i]->GetUniformId("u_fLightAmbient"), vsOffset);
		vsOffset += sizeof(float[4]) * 1;
		shaders[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders[i]->GetUniformId("u_UVInversed"), vsOffset);
		vsOffset += sizeof(float[4]) * 1;
		AssignPixelConstantBuffer(shaders[i]);
	}
	/*
	Shader* shaders_d[2];
	shaders_d[0] = shader_ad_distortion_;
	shaders_d[1] = shader_distortion_;

	for (int32_t i = 0; i < 2; i++)
	{
		auto isAd = i < 1;

		int vsOffset = 0;
		shaders_d[i]->AddVertexConstantLayout(CONSTANT_TYPE_MATRIX44, shaders_d[i]->GetUniformId("CBVS0.u_cameraProj"), vsOffset);

		vsOffset += sizeof(Effekseer::Matrix44);

		if (VertexType == EffekseerRenderer::ModelRendererVertexType::Instancing)
		{
			shaders_d[i]->AddVertexConstantLayout(CONSTANT_TYPE_MATRIX44, shaders_d[i]->GetUniformId("CBVS0.mModel_Inst"), vsOffset, N);
		}
		else
		{
			shaders_d[i]->AddVertexConstantLayout(CONSTANT_TYPE_MATRIX44, shaders_d[i]->GetUniformId("CBVS0.mModel"), vsOffset, N);
		}

		vsOffset += sizeof(Effekseer::Matrix44) * N;

		shaders_d[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders_d[i]->GetUniformId("CBVS0.fUV"), vsOffset, N);

		vsOffset += sizeof(float[4]) * N;

		if (isAd)
		{
			shaders_d[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders_d[i]->GetUniformId("CBVS0.fAlphaUV"), vsOffset, N);

			vsOffset += sizeof(float[4]) * N;

			shaders_d[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders_d[i]->GetUniformId("CBVS0.fUVDistortionUV"), vsOffset, N);

			vsOffset += sizeof(float[4]) * N;

			shaders_d[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders_d[i]->GetUniformId("CBVS0.fBlendUV"), vsOffset, N);

			vsOffset += sizeof(float[4]) * N;

			shaders_d[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders_d[i]->GetUniformId("CBVS0.fBlendAlphaUV"), vsOffset, N);

			vsOffset += sizeof(float[4]) * N;

			shaders_d[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders_d[i]->GetUniformId("CBVS0.fBlendUVDistortionUV"), vsOffset, N);

			vsOffset += sizeof(float[4]) * N;

			shaders_d[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders_d[i]->GetUniformId("CBVS0.fFlipbookParameter"), vsOffset);

			vsOffset += sizeof(float[4]) * 1;

			shaders_d[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders_d[i]->GetUniformId("CBVS0.fFlipbookIndexAndNextRate"), vsOffset, N);

			vsOffset += sizeof(float[4]) * N;

			shaders_d[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders_d[i]->GetUniformId("CBVS0.fModelAlphaThreshold"), vsOffset, N);

			vsOffset += sizeof(float[4]) * N;
		}

		shaders_d[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders_d[i]->GetUniformId("CBVS0.fModelColor"), vsOffset, N);

		vsOffset += sizeof(float[4]) * N;

		shaders_d[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders_d[i]->GetUniformId("CBVS0.fLightDirection"), vsOffset);

		vsOffset += sizeof(float[4]) * 1;

		shaders_d[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders_d[i]->GetUniformId("CBVS0.fLightColor"), vsOffset);

		vsOffset += sizeof(float[4]) * 1;

		shaders_d[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders_d[i]->GetUniformId("CBVS0.fLightAmbient"), vsOffset);

		vsOffset += sizeof(float[4]) * 1;

		shaders_d[i]->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shaders_d[i]->GetUniformId("CBVS0.u_UVInversed"), vsOffset);

		vsOffset += sizeof(float[4]) * 1;

		AssignDistortionPixelConstantBuffer(shaders_d[i]);
	}
	*/
}

ModelRenderer::ModelRenderer(RendererImplemented* renderer,
							 Shader* shader_ad_lit,
							 Shader* shader_ad_unlit,
							 Shader* shader_ad_distortion,
							 Shader* shader_lit,
							 Shader* shader_unlit,
							 Shader* shader_distortion)
	: m_renderer(renderer)
	, shader_ad_lit_(shader_ad_lit)
	, shader_ad_unlit_(shader_ad_unlit)
	, shader_ad_distortion_(shader_ad_distortion)
	, shader_lit_(shader_lit)
	, shader_unlit_(shader_unlit)
	, shader_distortion_(shader_distortion)
{
	graphicsDevice_ = renderer->GetGraphicsDevice().DownCast<Backend::GraphicsDevice>();
	if (false/*renderer->GetDeviceType() == OpenGLDeviceType::OpenGL3 || renderer->GetDeviceType() == OpenGLDeviceType::OpenGLES3*/)
	{
		VertexType = EffekseerRenderer::ModelRendererVertexType::Instancing;
		InitRenderer<InstanceCount>();
	}
	else
	{
		InitRenderer<1>();
	}
}

ModelRenderer::~ModelRenderer()
{
	ES_SAFE_DELETE(shader_unlit_);
	ES_SAFE_DELETE(shader_lit_);
	ES_SAFE_DELETE(shader_distortion_);

	ES_SAFE_DELETE(shader_ad_unlit_);
	ES_SAFE_DELETE(shader_ad_lit_);
	ES_SAFE_DELETE(shader_ad_distortion_);
}

ModelRendererRef ModelRenderer::Create(RendererImplemented* renderer)
{
	assert(renderer != nullptr);

	auto shaderCount = static_cast<size_t>(EffekseerRenderer::RendererShaderType::Material) + 1;
	std::vector<Shader*> shaders;
	shaders.resize(shaderCount);
	for (int i = 0; i < shaderCount; i++) {
		shaders[i] = Shader::Create(s_bgfx_model_context_[i].program_, std::move(s_bgfx_model_context_[i].uniforms_));
	}

	return ModelRendererRef(new ModelRenderer(renderer,
		shaders[static_cast<size_t>(EffekseerRenderer::RendererShaderType::AdvancedLit)],
		shaders[static_cast<size_t>(EffekseerRenderer::RendererShaderType::AdvancedUnlit)],
		shaders[static_cast<size_t>(EffekseerRenderer::RendererShaderType::AdvancedBackDistortion)],
		shaders[static_cast<size_t>(EffekseerRenderer::RendererShaderType::Lit)],
		shaders[static_cast<size_t>(EffekseerRenderer::RendererShaderType::Unlit)],
		shaders[static_cast<size_t>(EffekseerRenderer::RendererShaderType::BackDistortion)]));
}

void ModelRenderer::BeginRendering(const efkModelNodeParam& parameter, int32_t count, void* userData)
{
	BeginRendering_(m_renderer, parameter, count, userData);
}

void ModelRenderer::Rendering(const efkModelNodeParam& parameter, const InstanceParameter& instanceParameter, void* userData)
{
	Rendering_<RendererImplemented>(m_renderer, parameter, instanceParameter, userData);
}

void ModelRenderer::EndRendering(const efkModelNodeParam& parameter, void* userData)
{
	if (collector_.DoRequireAdvancedRenderer())
	{
		if (parameter.BasicParameterPtr->MaterialType == Effekseer::RendererMaterialType::BackDistortion)
		{
			;// m_renderer->SetVertexArray(m_va[2]);
		}
		else if (parameter.BasicParameterPtr->MaterialType == Effekseer::RendererMaterialType::Lighting)
		{
			;// m_renderer->SetVertexArray(m_va[0]);
		}
		else
		{
			;// m_renderer->SetVertexArray(m_va[1]);
		}
	}
	else
	{
		if (parameter.BasicParameterPtr->MaterialType == Effekseer::RendererMaterialType::BackDistortion)
		{
			;// m_renderer->SetVertexArray(m_va[5]);
		}
		else if (parameter.BasicParameterPtr->MaterialType == Effekseer::RendererMaterialType::Lighting)
		{
			;// m_renderer->SetVertexArray(m_va[3]);
		}
		else
		{
			;// m_renderer->SetVertexArray(m_va[4]);
		}
	}

	if (parameter.ModelIndex < 0)
	{
		return;
	}

	Effekseer::ModelRef model = nullptr;

	if (parameter.IsProceduralMode)
	{
		model = parameter.EffectPointer->GetProceduralModel(parameter.ModelIndex);
	}
	else
	{
		model = parameter.EffectPointer->GetModel(parameter.ModelIndex);
	}

	if (model == nullptr)
	{
		return;
	}

// 	model->StoreBufferToGPU(graphicsDevice_.Get());
// 	if (!model->GetIsBufferStoredOnGPU())
// 	{
// 		return;
// 	}
// 
// 	if (m_renderer->GetRenderMode() == Effekseer::RenderMode::Wireframe)
// 	{
// 		model->GenerateWireIndexBuffer(graphicsDevice_.Get());
// 		if (!model->GetIsWireIndexBufferGenerated())
// 		{
// 			return;
// 		}
// 	}

	if (VertexType == EffekseerRenderer::ModelRendererVertexType::Instancing)
	{
		EndRendering_<RendererImplemented, Shader, Effekseer::Model, true, InstanceCount>(
			m_renderer, shader_ad_lit_, shader_ad_unlit_, shader_ad_distortion_, shader_lit_, shader_unlit_, shader_distortion_, parameter, userData);
	}
	else
	{
		EndRendering_<RendererImplemented, Shader, Effekseer::Model, false, 1>(
			m_renderer, shader_ad_lit_, shader_ad_unlit_, shader_ad_distortion_, shader_lit_, shader_unlit_, shader_distortion_, parameter, userData);
	}
}

} // namespace EffekseerRendererBGFX
