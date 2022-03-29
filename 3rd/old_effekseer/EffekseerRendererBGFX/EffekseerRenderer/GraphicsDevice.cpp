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
			ES_SAFE_RELEASE(graphicsDevice_);
		}

		bool RenderPass::Init(Effekseer::FixedSizeVector<Effekseer::Backend::TextureRef, Effekseer::Backend::RenderTargetMax>& textures, Effekseer::Backend::TextureRef depthTexture)
		{
			return true;
		}

		Effekseer::Backend::VertexBufferRef GraphicsDevice::CreateVertexBuffer(int32_t size, const void* initialData, bool isDynamic)
		{
			return EffekseerRendererBGFX::Backend::VertexBuffer::Create(size, *ModelRenderer::model_vertex_layout_, initialData);
		}

		Effekseer::Backend::IndexBufferRef GraphicsDevice::CreateIndexBuffer(int32_t elementCount, const void* initialData, Effekseer::Backend::IndexBufferStrideType stride)
		{
			return EffekseerRendererBGFX::Backend::IndexBuffer::Create(elementCount, Effekseer::Backend::IndexBufferStrideType::Stride4, initialData);
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

		Effekseer::Backend::RenderPassRef GraphicsDevice::CreateRenderPass(Effekseer::FixedSizeVector<Effekseer::Backend::TextureRef, Effekseer::Backend::RenderTargetMax>& textures, Effekseer::Backend::TextureRef& depthTexture)
		{
			auto ret = Effekseer::MakeRefPtr<RenderPass>(this);

			if (!ret->Init(textures, depthTexture))
			{
				return nullptr;
			}

			return ret;
		}
	} // namespace Backend
} // namespace EffekseerRendererBGFX
