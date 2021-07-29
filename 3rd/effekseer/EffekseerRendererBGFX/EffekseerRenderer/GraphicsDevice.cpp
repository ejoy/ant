#include "GraphicsDevice.h"
#include "EffekseerRendererBGFX.Base.h"
#include "EffekseerRendererBGFX.RendererImplemented.h"
#include "EffekseerRendererBGFX.RenderResources.h"
#include "EffekseerRendererBGFX.VertexBuffer.h"
#include "EffekseerRendererBGFX.IndexBuffer.h"
#include "EffekseerRendererBGFX.ModelRenderer.h"

namespace EffekseerRendererBGFX {
	namespace Backend {

		bool PipelineState::Init(const Effekseer::Backend::PipelineStateParameter& param)
		{
			param_ = param;
			return true;
		}

		RenderPass::RenderPass(GraphicsDevice* graphicsDevice)
			: graphicsDevice_(graphicsDevice)
		{
			ES_SAFE_ADDREF(graphicsDevice_);
		}

		RenderPass::~RenderPass()
		{
			//if (buffer_ > 0)
			//{
			//	GLExt::glDeleteFramebuffers(1, &buffer_);
			//	buffer_ = 0;
			//}

			//ES_SAFE_RELEASE(graphicsDevice_);
		}

		bool RenderPass::Init(Effekseer::FixedSizeVector<Effekseer::Backend::TextureRef, Effekseer::Backend::RenderTargetMax>& textures, Effekseer::Backend::TextureRef depthTexture)
		{
			return true;
		}

		GraphicsDevice::GraphicsDevice()
		{
		}

		GraphicsDevice::~GraphicsDevice()
		{
		}

		Effekseer::Backend::VertexBufferRef GraphicsDevice::CreateVertexBuffer(int32_t size, const void* initialData, bool isDynamic)
		{
			return EffekseerRendererBGFX::Backend::VertexBuffer::Create(size, *ModelRenderer::model_vertex_layout_, initialData);
			//auto ret = Effekseer::MakeRefPtr<VertexBuffer>(this);

			//if (!ret->Init(size, isDynamic))
			//{
			//	return nullptr;
			//}

			//ret->UpdateData(initialData, size, 0);

			//return ret;
			//return nullptr;
		}

		Effekseer::Backend::IndexBufferRef GraphicsDevice::CreateIndexBuffer(int32_t elementCount, const void* initialData, Effekseer::Backend::IndexBufferStrideType stride)
		{
			return EffekseerRendererBGFX::Backend::IndexBuffer::Create(elementCount, Effekseer::Backend::IndexBufferStrideType::Stride4, initialData);
			//auto ret = Effekseer::MakeRefPtr<IndexBuffer>(this);

			//if (!ret->Init(elementCount, stride == Effekseer::Backend::IndexBufferStrideType::Stride4 ? 4 : 2))
			//{
			//	return nullptr;
			//}

			//ret->UpdateData(initialData, elementCount * (stride == Effekseer::Backend::IndexBufferStrideType::Stride4 ? 4 : 2), 0);

			//return ret;
			//return nullptr;
		}

		Effekseer::Backend::TextureRef GraphicsDevice::CreateTexture(const Effekseer::Backend::TextureParameter& param)
		{
			auto ret = Effekseer::MakeRefPtr<Texture>();

			if (!ret->Init(param))
			{
				return nullptr;
			}

			return ret;
		}

		Effekseer::Backend::TextureRef GraphicsDevice::CreateRenderTexture(const Effekseer::Backend::RenderTextureParameter& param)
		{
			auto ret = Effekseer::MakeRefPtr<Texture>();

			if (!ret->Init(param))
			{
				return nullptr;
			}

			return ret;
		}

		Effekseer::Backend::TextureRef GraphicsDevice::CreateDepthTexture(const Effekseer::Backend::DepthTextureParameter& param)
		{
			auto ret = Effekseer::MakeRefPtr<Texture>();

			if (!ret->Init(param))
			{
				return nullptr;
			}

			return ret;
		}

		Effekseer::Backend::UniformBufferRef GraphicsDevice::CreateUniformBuffer(int32_t size, const void* initialData)
		{
			return nullptr;
		}

		Effekseer::Backend::VertexLayoutRef GraphicsDevice::CreateVertexLayout(const Effekseer::Backend::VertexLayoutElement* elements, int32_t elementCount)
		{

			return nullptr;
		}

		Effekseer::Backend::RenderPassRef GraphicsDevice::CreateRenderPass(Effekseer::FixedSizeVector<Effekseer::Backend::TextureRef, Effekseer::Backend::RenderTargetMax>& textures, Effekseer::Backend::TextureRef& depthTexture)
		{
			auto ret = Effekseer::MakeRefPtr<RenderPass>(this);

			if (!ret->Init(textures, depthTexture))
			{
				return nullptr;
			}

			return ret;
		}

		Effekseer::Backend::PipelineStateRef GraphicsDevice::CreatePipelineState(const Effekseer::Backend::PipelineStateParameter& param)
		{
			auto ret = Effekseer::MakeRefPtr<PipelineState>();

			if (!ret->Init(param))
			{
				return nullptr;
			}

			return ret;
		}

		Effekseer::Backend::ShaderRef GraphicsDevice::CreateShaderFromKey(const char* key)
		{
			return nullptr;
		}

		Effekseer::Backend::ShaderRef GraphicsDevice::CreateShaderFromCodes(const char* vsCode, const char* psCode, Effekseer::Backend::UniformLayoutRef layout)
		{
			return nullptr;
		}

		void GraphicsDevice::Draw(const Effekseer::Backend::DrawParameter& drawParam)
		{
		}

		void GraphicsDevice::BeginRenderPass(Effekseer::Backend::RenderPassRef& renderPass, bool isColorCleared, bool isDepthCleared, Effekseer::Color clearColor)
		{
		}

		void GraphicsDevice::EndRenderPass()
		{
		}

		bool GraphicsDevice::UpdateUniformBuffer(Effekseer::Backend::UniformBufferRef& buffer, int32_t size, int32_t offset, const void* data)
		{
			return true;
		}

		Effekseer::Backend::TextureRef GraphicsDevice::CreateTexture(bgfx_texture_handle_t buffer, bool hasMipmap, const std::function<void()>& onDisposed)
		{
			auto ret = Effekseer::MakeRefPtr<Texture>(/*this*/);

			//if (!ret->Init(buffer, hasMipmap, onDisposed))
			//{
			//	return nullptr;
			//}

			return ret;
		}

	} // namespace Backend
} // namespace EffekseerRendererBGFX
