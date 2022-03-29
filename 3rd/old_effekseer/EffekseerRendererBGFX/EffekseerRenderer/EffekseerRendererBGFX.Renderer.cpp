//#include "bgfx_utils.h"
////----------------------------------------------------------------------------------
//// Include
////----------------------------------------------------------------------------------
#include "EffekseerRendererBGFX.Renderer.h"
#include "EffekseerRendererBGFX.RenderState.h"
#include "EffekseerRendererBGFX.RendererImplemented.h"

#include "EffekseerRendererBGFX.IndexBuffer.h"
#include "EffekseerRendererBGFX.MaterialLoader.h"
#include "EffekseerRendererBGFX.ModelRenderer.h"
#include "EffekseerRendererBGFX.Shader.h"
#include "EffekseerRendererBGFX.VertexBuffer.h"
#include "EffekseerRendererBGFX.RenderResources.h"
#include "EffekseerRendererBGFX.ModelLoader.h"
#include "EffekseerRendererBGFX.TextureLoader.h"
#include "../../EffekseerRendererCommon/EffekseerRenderer.Renderer_Impl.h"
#include "../../EffekseerRendererCommon/EffekseerRenderer.RibbonRendererBase.h"
#include "../../EffekseerRendererCommon/EffekseerRenderer.RingRendererBase.h"
#include "../../EffekseerRendererCommon/EffekseerRenderer.SpriteRendererBase.h"
#include "../../EffekseerRendererCommon/EffekseerRenderer.TrackRendererBase.h"

#ifdef __EFFEKSEER_RENDERER_INTERNAL_LOADER__
#include "../../EffekseerRendererCommon/TextureLoaderGL.h"
#endif

#include "GraphicsDevice.h"

namespace EffekseerRendererBGFX
{

::Effekseer::TextureLoaderRef CreateTextureLoader(::Effekseer::FileInterface* fileInterface, ::Effekseer::ColorSpaceType colorSpaceType)
{
	auto bgfxgd = new Backend::GraphicsDevice();
#ifdef __EFFEKSEER_RENDERER_INTERNAL_LOADER__
	auto ret = ::Effekseer::TextureLoaderRef(new EffekseerRenderer::TextureLoader(bgfxgd, fileInterface));
	ES_SAFE_RELEASE(bgfxgd);
	return ret;
#else
	auto ret = ::Effekseer::TextureLoaderRef(new TextureLoader(bgfxgd, fileInterface));
	ES_SAFE_RELEASE(bgfxgd);
	return ret;
#endif
}

::Effekseer::TextureLoaderRef CreateTextureLoader(
	Effekseer::Backend::GraphicsDeviceRef graphicsDevice,
	::Effekseer::FileInterface* fileInterface,
	::Effekseer::ColorSpaceType colorSpaceType)
{
#ifdef __EFFEKSEER_RENDERER_INTERNAL_LOADER__
	return ::Effekseer::MakeRefPtr<EffekseerRenderer::TextureLoader>(graphicsDevice.Get(), fileInterface, colorSpaceType);
#else
	return ::Effekseer::MakeRefPtr<TextureLoader>(graphicsDevice.Get(), fileInterface, colorSpaceType);
#endif
}

::Effekseer::ModelLoaderRef CreateModelLoader(::Effekseer::FileInterface* fileInterface)
{
	auto ret = Effekseer::MakeRefPtr<EffekseerRendererBGFX::ModelLoader>(::Effekseer::MakeRefPtr<Backend::GraphicsDevice>(), fileInterface);
	return ret;
}

::Effekseer::MaterialLoaderRef CreateMaterialLoader(Renderer* renderer,
													::Effekseer::FileInterface* fileInterface)
{
	return ::Effekseer::MakeRefPtr<MaterialLoader>(renderer, fileInterface);
}

std::vector<bgfx_context> Renderer::s_bgfx_sprite_context_;

RendererRef Renderer::Create(int32_t squareMaxCount)
{
	return Create(Effekseer::MakeRefPtr<Backend::GraphicsDevice>(), squareMaxCount);
}

RendererRef Renderer::Create(Effekseer::Backend::GraphicsDeviceRef graphicsDevice, int32_t squareMaxCount)
{
	auto renderer = ::Effekseer::MakeRefPtr<RendererImplemented>(squareMaxCount, graphicsDevice.DownCast<Backend::GraphicsDevice>());
	if (renderer->Initialize())
	{
		return renderer;
	}
	return nullptr;
}

int32_t RendererImplemented::GetIndexSpriteCount() const
{
	int vsSize = EffekseerRenderer::GetMaximumVertexSizeInAllTypes() * m_squareMaxCount * 4;

	size_t size = sizeof(EffekseerRenderer::SimpleVertex);
	size = (std::min)(size, sizeof(EffekseerRenderer::DynamicVertex));
	size = (std::min)(size, sizeof(EffekseerRenderer::LightingVertex));

	return (int32_t)(vsSize / size / 4 + 1);
}

RendererImplemented::RendererImplemented(int32_t squareMaxCount, Backend::GraphicsDeviceRef graphicsDevice)
	: m_squareMaxCount(squareMaxCount)
	, m_renderState(nullptr)
	, m_restorationOfStates(true)
	, m_standardRenderer(nullptr)
	, m_distortingCallback(nullptr)
{
	graphicsDevice_ = graphicsDevice;
	m_vertexBuffers.resize(static_cast<size_t>(EffekseerRenderer::RendererShaderType::Material) + 1 + 1);
}

RendererImplemented::~RendererImplemented()
{
	GetImpl()->DeleteProxyTextures(this);

	ES_SAFE_DELETE(m_distortingCallback);

	ES_SAFE_DELETE(m_standardRenderer);
	for (auto shader : shaders_) {
		ES_SAFE_DELETE(shader);
	}

	ES_SAFE_DELETE(m_renderState);
	for (auto bgfxBuffer : m_vertexBuffers) {
		ES_SAFE_DELETE(bgfxBuffer);
	}
	ES_SAFE_DELETE(m_indexBuffer);
	ES_SAFE_DELETE(m_indexBufferForWireframe);
}

void RendererImplemented::GenerateIndexData()
{
	if (indexBufferStride_ == 2) {
		GenerateIndexDataStride<uint16_t>();
	}
	else if (indexBufferStride_ == 4) {
		GenerateIndexDataStride<uint32_t>();
	}
}

template <typename T>
void RendererImplemented::GenerateIndexDataStride()
{
	auto indexBuffer = m_indexBuffer;
	// generate an index buffer
	if (indexBuffer != nullptr) {
		indexBuffer->Lock();
		for (int i = 0; i < GetIndexSpriteCount(); i++) {
			std::array<T, 6> buf;
			buf[0] = (T)(3 + 4 * i);
			buf[1] = (T)(1 + 4 * i);
			buf[2] = (T)(0 + 4 * i);
			buf[3] = (T)(3 + 4 * i);
			buf[4] = (T)(0 + 4 * i);
			buf[5] = (T)(2 + 4 * i);
			memcpy(indexBuffer->GetBufferDirect(6), buf.data(), sizeof(T) * 6);
		}
		indexBuffer->Unlock();
	}

	auto indexBufferForWireframe = m_indexBufferForWireframe;
	// generate an index buffer for a wireframe
	if (indexBufferForWireframe != nullptr) {
		indexBufferForWireframe->Lock();
		for (int i = 0; i < GetIndexSpriteCount(); i++) {
			std::array<T, 8> buf;
			buf[0] = (T)(0 + 4 * i);
			buf[1] = (T)(1 + 4 * i);
			buf[2] = (T)(2 + 4 * i);
			buf[3] = (T)(3 + 4 * i);
			buf[4] = (T)(0 + 4 * i);
			buf[5] = (T)(2 + 4 * i);
			buf[6] = (T)(1 + 4 * i);
			buf[7] = (T)(3 + 4 * i);
			memcpy(indexBufferForWireframe->GetBufferDirect(8), buf.data(), sizeof(T) * 8);
		}
		indexBufferForWireframe->Unlock();
	}
}

bool RendererImplemented::Initialize()
{
	if (GetIndexSpriteCount() * 4 > 65536) {
		indexBufferStride_ = 4;
	}

	SetSquareMaxCount(m_squareMaxCount);

	m_renderState = new RenderState(this);

	auto shaderCount = static_cast<size_t>(EffekseerRenderer::RendererShaderType::Material) + 1;
	shaders_.resize(shaderCount);
	for (int i = 0; i < shaderCount; i++) {
		shaders_[i] = Shader::Create(this, s_bgfx_sprite_context_[i].program_, std::move(s_bgfx_sprite_context_[i].uniforms_));
	}
	
	auto applyPSAdvancedRendererParameterTexture = [](Shader* shader, int32_t offset) -> void {
		shader->SetTextureSlot(0 + offset, shader->GetUniformId("s_sampler_alphaTex"));
		shader->SetTextureSlot(1 + offset, shader->GetUniformId("s_sampler_uvDistortionTex"));
		shader->SetTextureSlot(2 + offset, shader->GetUniformId("s_sampler_blendTex"));
		shader->SetTextureSlot(3 + offset, shader->GetUniformId("s_sampler_blendAlphaTex"));
		shader->SetTextureSlot(4 + offset, shader->GetUniformId("s_sampler_blendUVDistortionTex"));
	};

	auto shader_unlit = shaders_[static_cast<size_t>(EffekseerRenderer::RendererShaderType::Unlit)];
	auto shader_ad_unlit = shaders_[static_cast<size_t>(EffekseerRenderer::RendererShaderType::AdvancedUnlit)];
	for (auto& shader : { shader_ad_unlit, shader_unlit }) {
		shader->SetVertexConstantBufferSize(sizeof(EffekseerRenderer::StandardRendererVertexBuffer));
		shader->SetPixelConstantBufferSize(sizeof(EffekseerRenderer::PixelConstantBuffer));
		
		shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("u_vsFlipbookParameter"), sizeof(Effekseer::Matrix44) * 2 + sizeof(float) * 4);
		shader->AddVertexConstantLayout(CONSTANT_TYPE_MATRIX44, shader->GetUniformId("u_camera"), 0);
		shader->AddVertexConstantLayout(CONSTANT_TYPE_MATRIX44, shader->GetUniformId("u_cameraProj"), sizeof(Effekseer::Matrix44));
		shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("u_UVInversed"), sizeof(Effekseer::Matrix44) * 2);
		shader->SetTextureSlot(0, shader->GetUniformId("s_sampler_colorTex"));
		AssignPixelConstantBuffer(shader);
	}

	applyPSAdvancedRendererParameterTexture(shader_ad_unlit, 1);
	shader_unlit->SetTextureSlot(1, shader_unlit->GetUniformId("s_sampler_depthTex"));
	shader_ad_unlit->SetTextureSlot(6, shader_ad_unlit->GetUniformId("s_sampler_depthTex"));

	//vao_unlit_ = VertexArray::Create(graphicsDevice_, shader_unlit_, GetVertexBuffer(), GetIndexBuffer());
	//vao_ad_unlit_ = VertexArray::Create(graphicsDevice_, shader_ad_unlit_, GetVertexBuffer(), GetIndexBuffer());

	// Distortion
	//EffekseerRendererBGFX::ShaderAttribInfo sprite_attribs_normal_ad[11] = {
	//	{"Input_Pos", GL_FLOAT, 3, 0, false},
	//	{"Input_Color", GL_UNSIGNED_BYTE, 4, 12, true},
	//	{"Input_Normal", GL_UNSIGNED_BYTE, 4, 16, true},
	//	{"Input_Tangent", GL_UNSIGNED_BYTE, 4, 20, true},
	//	{"Input_UV1", GL_FLOAT, 2, 24, false},
	//	{"Input_UV2", GL_FLOAT, 2, 32, false},

	//	{"Input_Alpha_Dist_UV", GL_FLOAT, 4, sizeof(float) * 10, false},
	//	{"Input_BlendUV", GL_FLOAT, 2, sizeof(float) * 14, false},
	//	{"Input_Blend_Alpha_Dist_UV", GL_FLOAT, 4, sizeof(float) * 16, false},
	//	{"Input_FlipbookIndex", GL_FLOAT, 1, sizeof(float) * 20, false},
	//	{"Input_AlphaThreshold", GL_FLOAT, 1, sizeof(float) * 21, false},
	//};

	//EffekseerRendererBGFX::ShaderAttribInfo sprite_attribs_normal[6] = {
	//	{"Input_Pos", GL_FLOAT, 3, 0, false},
	//	{"Input_Color", GL_UNSIGNED_BYTE, 4, 12, true},
	//	{"Input_Normal", GL_UNSIGNED_BYTE, 4, 16, true},
	//	{"Input_Tangent", GL_UNSIGNED_BYTE, 4, 20, true},
	//	{"Input_UV1", GL_FLOAT, 2, 24, false},
	//	{"Input_UV2", GL_FLOAT, 2, 32, false},
	//};

	//for (auto& shader : {shader_ad_distortion_, shader_distortion_})
	//{
	//	shader->SetVertexConstantBufferSize(sizeof(EffekseerRenderer::StandardRendererVertexBuffer));
	//	shader->SetPixelConstantBufferSize(sizeof(EffekseerRenderer::PixelConstantBufferDistortion));

	//	shader->AddVertexConstantLayout(CONSTANT_TYPE_MATRIX44, BGFX(create_uniform)("u_camera", bgfx::UniformType::Mat4)/*shader->GetUniformId("CBVS0.u_camera")*/, 0);

	//	shader->AddVertexConstantLayout(
	//		CONSTANT_TYPE_MATRIX44, BGFX(create_uniform)("u_cameraProj", bgfx::UniformType::Mat4)/*shader->GetUniformId("CBVS0.u_cameraProj")*/, sizeof(Effekseer::Matrix44));

	//	shader->AddVertexConstantLayout(
	//		CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("u_UVInversed", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("CBVS0.u_UVInversed")*/, sizeof(Effekseer::Matrix44) * 2);

	//	shader->SetTextureSlot(0, BGFX(create_uniform)("s_sampler_colorTex", bgfx::UniformType::Sampler)/*shader->GetUniformId("s_sampler_colorTex")*/);
	//	shader->SetTextureSlot(1, BGFX(create_uniform)("Sampler_sampler_backTex", bgfx::UniformType::Sampler)/*shader->GetUniformId("Sampler_sampler_backTex")*/);

	//	shader->AddVertexConstantLayout(CONSTANT_TYPE_VECTOR4,
	//		BGFX(create_uniform)("u_flipbookParameter", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("CBVS0.u_flipbookParameter")*/,
	//									sizeof(Effekseer::Matrix44) * 2 + sizeof(float) * 4);

	//	AssignDistortionPixelConstantBuffer(shader);
	//}

	//applyPSAdvancedRendererParameterTexture(shader_ad_distortion_, 2);
	//shader_distortion_->SetTextureSlot(2, BGFX(create_uniform)("s_sampler_depthTex", bgfx::UniformType::Sampler)/*shader_distortion_->GetUniformId("s_sampler_depthTex")*/);
	//shader_ad_distortion_->SetTextureSlot(7, BGFX(create_uniform)("s_sampler_depthTex", bgfx::UniformType::Sampler)/*shader_ad_distortion_->GetUniformId("s_sampler_depthTex")*/);

	//// Lit
	//for (auto shader : {shader_ad_lit_, shader_lit_})
	//{
	//	shader->SetVertexConstantBufferSize(sizeof(EffekseerRenderer::StandardRendererVertexBuffer));
	//	shader->SetPixelConstantBufferSize(sizeof(EffekseerRenderer::PixelConstantBuffer));

	//	shader->AddVertexConstantLayout(CONSTANT_TYPE_MATRIX44, BGFX(create_uniform)("u_camera", bgfx::UniformType::Mat4)/*shader->GetUniformId("CBVS0.u_camera")*/, 0);

	//	shader->AddVertexConstantLayout(
	//		CONSTANT_TYPE_MATRIX44, BGFX(create_uniform)("u_cameraProj", bgfx::UniformType::Mat4)/*shader->GetUniformId("CBVS0.u_cameraProj")*/, sizeof(Effekseer::Matrix44));

	//	shader->AddVertexConstantLayout(
	//		CONSTANT_TYPE_VECTOR4, BGFX(create_uniform)("u_UVInversed", BGFX_UNIFORM_TYPE_VEC4)/*shader->GetUniformId("CBVS0.u_UVInversed")*/, sizeof(Effekseer::Matrix44) * 2);

	//	shader->SetTextureSlot(0, BGFX(create_uniform)("s_sampler_colorTex", bgfx::UniformType::Sampler)/*shader->GetUniformId("s_sampler_colorTex")*/);
	//	shader->SetTextureSlot(1, BGFX(create_uniform)("Sampler_sampler_normalTex", bgfx::UniformType::Sampler)/*shader->GetUniformId("Sampler_sampler_normalTex")*/);

	//	AssignPixelConstantBuffer(shader);
	//}

	//applyPSAdvancedRendererParameterTexture(shader_ad_lit_, 2);
	//shader_lit_->SetTextureSlot(2, BGFX(create_uniform)("s_sampler_depthTex", bgfx::UniformType::Sampler)/*shader_lit_->GetUniformId("s_sampler_depthTex")*/);
	//shader_ad_lit_->SetTextureSlot(7, BGFX(create_uniform)("s_sampler_depthTex", bgfx::UniformType::Sampler)/*shader_ad_lit_->GetUniformId("s_sampler_depthTex")*/);


	//m_vao_wire_frame = VertexArray::Create(graphicsDevice_, shader_unlit_, GetVertexBuffer(), m_indexBufferForWireframe);

	m_standardRenderer = new EffekseerRenderer::StandardRenderer<RendererImplemented, Shader>(this);

	GetImpl()->isSoftParticleEnabled = true;// GetDeviceType() == OpenGLDeviceType::OpenGL3 || GetDeviceType() == OpenGLDeviceType::OpenGLES3;

	GetImpl()->CreateProxyTextures(this);

	return true;
}

void RendererImplemented::SetRestorationOfStatesFlag(bool flag)
{
	m_restorationOfStates = flag;
}

bool RendererImplemented::BeginRendering()
{
	impl->CalculateCameraProjectionMatrix();

	currentTextures_.clear();
	m_renderState->GetActiveState().Reset();
	//m_renderState->Update(true);

	m_renderState->GetActiveState().TextureIDs.fill(0);

	// reset renderer
	m_standardRenderer->ResetAndRenderingIfRequired();

	return true;
}

bool RendererImplemented::EndRendering()
{
	// reset renderer
	m_standardRenderer->ResetAndRenderingIfRequired();

	return true;
}

VertexBuffer* RendererImplemented::GetVertexBuffer()
{
	auto shaderType = m_standardRenderer->GetState().Collector.ShaderType;
	if (shaderType == EffekseerRenderer::RendererShaderType::Material) {
		auto mtlptr = m_standardRenderer->GetState().Collector.MaterialDataPtr;
		if (!mtlptr->IsSimpleVertex) {
			// TODO : custom material with custom data(data1,data2)
			assert(mtlptr->CustomData1 == 4 && mtlptr->CustomData2 == 0);
			return m_vertexBuffers[static_cast<int>(shaderType) + 1];
		}
	}
	return m_vertexBuffers[static_cast<int>(shaderType)];
}

IndexBuffer* RendererImplemented::GetIndexBuffer()
{
	return m_indexBuffer;
}

int32_t RendererImplemented::GetSquareMaxCount() const { return m_squareMaxCount; }

void RendererImplemented::SetSquareMaxCount(int32_t count)
{
	m_squareMaxCount = count;

	auto calculate_stride = [](EffekseerRenderer::RendererShaderType shaderType) {
		size_t stride = 0;
		if (shaderType == EffekseerRenderer::RendererShaderType::Lit
			|| shaderType == EffekseerRenderer::RendererShaderType::BackDistortion) {
			stride = sizeof(EffekseerRenderer::LightingVertex);
		}
		else if (shaderType == EffekseerRenderer::RendererShaderType::Unlit ||
			shaderType == EffekseerRenderer::RendererShaderType::Material) {
			stride = sizeof(EffekseerRenderer::SimpleVertex);
		}
		else if (shaderType == EffekseerRenderer::RendererShaderType::AdvancedLit
			|| shaderType == EffekseerRenderer::RendererShaderType::AdvancedBackDistortion) {
			stride = sizeof(EffekseerRenderer::AdvancedLightingVertex);
		}
		else if (shaderType == EffekseerRenderer::RendererShaderType::AdvancedUnlit) {
			stride = sizeof(EffekseerRenderer::AdvancedSimpleVertex);
		}

		return static_cast<int32_t>(stride);
	};

	size_t shaderTypeCount = static_cast<size_t>(EffekseerRenderer::RendererShaderType::Material) + 1;
	for (size_t i = 0; i < m_vertexBuffers.size(); i++) {
		if (i == 7)
		{
			// TODO : 
			auto vertexSize = sizeof(EffekseerRenderer::DynamicVertex) + sizeof(float) * 4; // (materialFile.GetCustomData1Count() + materialFile.GetCustomData2Count());
			m_vertexBuffers[i] = VertexBuffer::Create(vertexSize/* * m_squareMaxCount*/ * 4, true, *s_bgfx_sprite_context_[i].vertex_layout_);
		}
		else
		{
			m_vertexBuffers[i] = VertexBuffer::Create(calculate_stride(EffekseerRenderer::RendererShaderType(i))/* * m_squareMaxCount*/ * 4, true, *s_bgfx_sprite_context_[i].vertex_layout_);
		}
		if (m_vertexBuffers[i] == nullptr)
			return;
	}

	m_indexBuffer = IndexBuffer::Create(GetIndexSpriteCount() * 6, false, indexBufferStride_);
	if (m_indexBuffer == nullptr)
		return;

	m_indexBufferForWireframe = IndexBuffer::Create(GetIndexSpriteCount() * 8, false, indexBufferStride_);
	if (m_indexBufferForWireframe == nullptr)
		return;

	// generate index data
	GenerateIndexData();
}

::EffekseerRenderer::RenderStateBase* RendererImplemented::GetRenderState()
{
	return m_renderState;
}

::Effekseer::SpriteRendererRef RendererImplemented::CreateSpriteRenderer()
{
	return ::Effekseer::SpriteRendererRef(new ::EffekseerRenderer::SpriteRendererBase<RendererImplemented, false>(this));
}

::Effekseer::RibbonRendererRef RendererImplemented::CreateRibbonRenderer()
{
	return ::Effekseer::RibbonRendererRef(new ::EffekseerRenderer::RibbonRendererBase<RendererImplemented, false>(this));
}

::Effekseer::RingRendererRef RendererImplemented::CreateRingRenderer()
{
	return ::Effekseer::RingRendererRef(new ::EffekseerRenderer::RingRendererBase<RendererImplemented, false>(this));
}

::Effekseer::ModelRendererRef RendererImplemented::CreateModelRenderer()
{
	return ModelRenderer::Create(this);
}

::Effekseer::TrackRendererRef RendererImplemented::CreateTrackRenderer()
{
	return ::Effekseer::TrackRendererRef(new ::EffekseerRenderer::TrackRendererBase<RendererImplemented, false>(this));
}

::Effekseer::TextureLoaderRef RendererImplemented::CreateTextureLoader(::Effekseer::FileInterface* fileInterface)
{
#ifdef __EFFEKSEER_RENDERER_INTERNAL_LOADER__
	return ::Effekseer::MakeRefPtr<EffekseerRenderer::TextureLoader>(graphicsDevice_.Get(), fileInterface);
#else
	return ::Effekseer::MakeRefPtr<TextureLoader>(graphicsDevice_.Get(), fileInterface);;
#endif
}

::Effekseer::ModelLoaderRef RendererImplemented::CreateModelLoader(::Effekseer::FileInterface* fileInterface)
{
	return ::Effekseer::MakeRefPtr<EffekseerRendererBGFX::ModelLoader>(graphicsDevice_, fileInterface);
}

::Effekseer::MaterialLoaderRef RendererImplemented::CreateMaterialLoader(::Effekseer::FileInterface* fileInterface)
{
	return ::Effekseer::MakeRefPtr<MaterialLoader>(this, fileInterface);
}

void RendererImplemented::SetBackground(bgfx_texture_handle_t background, bool hasMipmap)
{
	//if (m_backgroundGL == nullptr)
	//{
	//	m_backgroundGL = graphicsDevice_->CreateTexture(background, hasMipmap, nullptr);
	//}
	//else
	//{
	//	auto texture = static_cast<Backend::Texture*>(m_backgroundGL.Get());
	//	texture->Init(background, hasMipmap, nullptr);
	//}

	//EffekseerRenderer::Renderer::SetBackground((background) ? m_backgroundGL : nullptr);
}

EffekseerRenderer::DistortingCallback* RendererImplemented::GetDistortingCallback()
{
	return m_distortingCallback;
}

void RendererImplemented::SetDistortingCallback(EffekseerRenderer::DistortingCallback* callback)
{
	ES_SAFE_DELETE(m_distortingCallback);
	m_distortingCallback = callback;
}

void RendererImplemented::SetVertexBuffer(VertexBuffer* vertexBuffer, int32_t size)
{
	BGFX(encoder_set_transient_vertex_buffer)(encoder_, 0, vertexBuffer->GetInterface(), 0, vertexBuffer->GetSize()/size);
}

/*
void RendererImplemented::SetVertexBuffer(bgfx_dynamic_vertex_buffer_handle_t vertexBuffer, int32_t size)
{
	//if (m_currentVertexArray == nullptr || m_currentVertexArray->GetVertexBuffer() == nullptr)
	//{
		//GLExt::glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
	BGFX(set_dynamic_vertex_buffer)(0, vertexBuffer, 0, size);
	//}
}
*/
void RendererImplemented::SetIndexBuffer(IndexBuffer* indexBuffer)
{
	//if (m_currentVertexArray == nullptr || m_currentVertexArray->GetIndexBuffer() == nullptr)
	//{
	//	//GLExt::glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer->GetInterface());
	//	bgfx::setIndexBuffer(indexBuffer->GetInterface());
	//	indexBufferCurrentStride_ = indexBuffer->GetStride();
	//}
	//else
	//{
	//	indexBufferCurrentStride_ = m_currentVertexArray->GetIndexBuffer()->GetStride();
	//}
}

void RendererImplemented::SetVertexBuffer(const Effekseer::Backend::VertexBufferRef& vertexBuffer, int32_t stride)
{
	auto vb = static_cast<Backend::VertexBuffer*>(vertexBuffer.Get());
	//SetVertexBuffer(vb->GetBuffer(), size);

	BGFX(encoder_set_dynamic_vertex_buffer)(encoder_, 0, vb->GetInterface(), 0, vb->GetSize() / stride);
}

void RendererImplemented::SetIndexBuffer(const Effekseer::Backend::IndexBufferRef& indexBuffer)
{
	auto ib = static_cast<Backend::IndexBuffer*>(indexBuffer.Get());
	//SetIndexBuffer(ib->GetBuffer());
	BGFX(encoder_set_dynamic_index_buffer)(encoder_, ib->GetInterface(), 0, ib->GetElementCount());
}

void RendererImplemented::SetVertexArray(VertexArray* vertexArray)
{
	//m_currentVertexArray = vertexArray;
}

void RendererImplemented::SetLayout(Shader* shader)
{

}

void RendererImplemented::DoDraw()
{
	if (currentShader) {
		for (int32_t i = 0; i < currentTextures_.size(); i++) {
			if (currentShader->GetTextureSlotEnable(i)) {
				BGFX(encoder_set_texture)(encoder_, i, currentShader->GetTextureSlot(i), currentTextures_[i].texture, currentTextures_[i].flags);
			}
		}
		BGFX(encoder_set_state)(encoder_, current_state_, 0);
		currentShader->Submit();
	}
}

void RendererImplemented::DrawSprites(int32_t spriteCount, int32_t vertexOffset)
{
	impl->drawcallCount++;
	impl->drawvertexCount += spriteCount * 4;

	auto indexBuffer = GetIndexBuffer();
	BGFX(encoder_set_dynamic_index_buffer)(encoder_, indexBuffer->GetInterface(), 0/*vertexOffset / 4 * 6*/, spriteCount * 6);
	indexBufferCurrentStride_ = indexBuffer->GetStride();

	DoDraw();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void RendererImplemented::DrawPolygon(int32_t vertexCount, int32_t indexCount)
{
	impl->drawcallCount++;
	impl->drawvertexCount += vertexCount;

	DoDraw();
}

void RendererImplemented::DrawPolygonInstanced(int32_t vertexCount, int32_t indexCount, int32_t instanceCount)
{

}

Shader* RendererImplemented::GetShader(::EffekseerRenderer::RendererShaderType type) const
{
	return shaders_[static_cast<int>(type)];
}

void RendererImplemented::BeginShader(Shader* shader)
{
	shader->BeginScene();

	assert(currentShader == nullptr);
	currentShader = shader;
}

void RendererImplemented::EndShader(Shader* shader)
{
	assert(currentShader == shader);
	currentShader = nullptr;

	shader->EndScene();
}

void RendererImplemented::SetVertexBufferToShader(const void* data, int32_t size, int32_t dstOffset)
{
	assert(currentShader != nullptr);
	auto p = static_cast<uint8_t*>(currentShader->GetVertexConstantBuffer()) + dstOffset;
	memcpy(p, data, size);
}

void RendererImplemented::SetPixelBufferToShader(const void* data, int32_t size, int32_t dstOffset)
{
	assert(currentShader != nullptr);
	auto p = static_cast<uint8_t*>(currentShader->GetPixelConstantBuffer()) + dstOffset;
	memcpy(p, data, size);
}

void RendererImplemented::SetTextures(Shader* shader, Effekseer::Backend::TextureRef* textures, int32_t count)
{
	for (int i = count; i < currentTextures_.size(); i++) {
		m_renderState->GetActiveState().TextureIDs[i] = 0;
	}

	currentTextures_.resize(count);

	for (int32_t i = 0; i < count; i++) {
// 		bgfx_texture_handle_t id;
		if (textures[i] != nullptr) {
			auto texture = static_cast<Backend::Texture*>(textures[i].Get());
			currentTextures_[i].texture = texture->GetBuffer();
		}

		auto& activeState = m_renderState->GetActiveState();
// 		if (textures[i] != nullptr) {
// 			activeState.TextureIDs[i] = id.idx;
// 			currentTextures_[i].texture = textures[i];
// 		} else {
// 			activeState.TextureIDs[i] = 0;
// 			currentTextures_[i].texture.Reset();
// 		}

		if (shader->GetTextureSlotEnable(i)) {
			uint32_t flags = 0;
			auto filter_ = activeState.TextureFilterTypes[i];
			if (filter_ == ::Effekseer::TextureFilterType::Nearest) {
				flags |= BGFX_SAMPLER_MAG_POINT;
			}

			if (textures[i]->GetHasMipmap()) {
				if (filter_ == ::Effekseer::TextureFilterType::Nearest) {
					flags |= BGFX_SAMPLER_MIP_POINT;
				}
			} else {
				if (filter_ == ::Effekseer::TextureFilterType::Nearest) {
					flags |= BGFX_SAMPLER_MIN_POINT;
				}
			}

			auto wrap_ = activeState.TextureWrapTypes[i];
			if (wrap_ == ::Effekseer::TextureWrapType::Repeat) {
				flags |= BGFX_SAMPLER_U_MIRROR | BGFX_SAMPLER_V_MIRROR | BGFX_SAMPLER_W_MIRROR;
			} else {
				flags |= BGFX_SAMPLER_U_CLAMP | BGFX_SAMPLER_V_CLAMP | BGFX_SAMPLER_W_CLAMP;
			}
			currentTextures_[i].flags = flags;
			//BGFX(set_texture)(i, shader->GetTextureSlot(i), id, flags);
		}
	}
}

void RendererImplemented::ResetRenderState()
{
	m_renderState->GetActiveState().Reset();
	m_renderState->Update(true);
}

bool RendererImplemented::IsVertexArrayObjectSupported() const
{
	return false;// GLExt::IsSupportedVertexArray();
}

void AssignPixelConstantBuffer(Shader* shader)
{
	int psOffset = 0;
	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fLightDirection"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fLightColor"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fLightAmbient"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fFlipbookParameter"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fUVDistortionParameter"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fBlendTextureParameter"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fCameraFrontDirection"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fFalloffParameter"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fFalloffBeginColor"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fFalloffEndColor"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fEmissiveScaling"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fEdgeColor"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fEdgeParameter"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("softParticleParam"), psOffset);
	psOffset += sizeof(float[4]) * 1;
	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("reconstructionParam1"), psOffset);
	psOffset += sizeof(float[4]) * 1;
	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("reconstructionParam2"), psOffset);
	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("mUVInversedBack"), psOffset);
	psOffset += sizeof(float[4]) * 1;
}

void AssignDistortionPixelConstantBuffer(Shader* shader)
{
	int psOffset = 0;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("g_scale"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("mUVInversedBack"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fFlipbookParameter"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(
		CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fUVDistortionParameter"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(
		CONSTANT_TYPE_VECTOR4, shader->GetUniformId("fBlendTextureParameter"), psOffset);

	psOffset += sizeof(float[4]) * 1;

	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("softParticleParam"), psOffset);
	psOffset += sizeof(float[4]) * 1;
	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("reconstructionParam1"), psOffset);
	psOffset += sizeof(float[4]) * 1;
	shader->AddPixelConstantLayout(CONSTANT_TYPE_VECTOR4, shader->GetUniformId("reconstructionParam2"), psOffset);
	psOffset += sizeof(float[4]) * 1;
}

} // namespace EffekseerRendererBGFX
