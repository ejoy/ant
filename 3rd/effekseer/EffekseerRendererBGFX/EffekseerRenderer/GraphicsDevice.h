#pragma once

#include "EffekseerRendererBGFX.Base.h"
#include <Effekseer.h>
#include <assert.h>
#include <functional>
#include <set>


namespace EffekseerRendererBGFX
{
namespace Backend
{

class GraphicsDevice;
class VertexBuffer;
class IndexBuffer;
class UniformBuffer;
class Shader;
class VertexLayout;
class FrameBuffer;
class Texture;
class RenderPass;
class PipelineState;
class UniformLayout;

using GraphicsDeviceRef = Effekseer::RefPtr<GraphicsDevice>;
using VertexBufferRef = Effekseer::RefPtr<VertexBuffer>;
using IndexBufferRef = Effekseer::RefPtr<IndexBuffer>;
using UniformBufferRef = Effekseer::RefPtr<UniformBuffer>;
using ShaderRef = Effekseer::RefPtr<Shader>;
using VertexLayoutRef = Effekseer::RefPtr<VertexLayout>;
using FrameBufferRef = Effekseer::RefPtr<FrameBuffer>;
using TextureRef = Effekseer::RefPtr<Texture>;
using RenderPassRef = Effekseer::RefPtr<RenderPass>;
using PipelineStateRef = Effekseer::RefPtr<PipelineState>;
using UniformLayoutRef = Effekseer::RefPtr<UniformLayout>;

class DeviceObject
{
private:
public:
	//virtual void OnLostDevice();

	//virtual void OnResetDevice();
};

class PipelineState
	: public Effekseer::Backend::PipelineState
{
private:
	Effekseer::Backend::PipelineStateParameter param_;

public:
	PipelineState() = default;
	~PipelineState() = default;

	bool Init(const Effekseer::Backend::PipelineStateParameter& param);

	const Effekseer::Backend::PipelineStateParameter& GetParam() const
	{
		return param_;
	}
};

class RenderPass
	: public Effekseer::Backend::RenderPass
{
private:
	GraphicsDevice* graphicsDevice_ = nullptr;
	Effekseer::FixedSizeVector<Effekseer::Backend::TextureRef, Effekseer::Backend::RenderTargetMax> textures_;
	Effekseer::Backend::TextureRef depthTexture_;

public:
	RenderPass(GraphicsDevice* graphicsDevice);
	~RenderPass() override;

	bool Init(Effekseer::FixedSizeVector<Effekseer::Backend::TextureRef, Effekseer::Backend::RenderTargetMax>& textures, Effekseer::Backend::TextureRef depthTexture);

	//GLuint GetBuffer() const
	//{
	//	return buffer_;
	//}
};

class GraphicsDevice
	: public Effekseer::Backend::GraphicsDevice
{
public:
	GraphicsDevice(/*OpenGLDeviceType deviceType, bool isExtensionsEnabled = true*/);

	~GraphicsDevice() override;

	Effekseer::Backend::VertexBufferRef CreateVertexBuffer(int32_t size, const void* initialData, bool isDynamic) override;

	Effekseer::Backend::IndexBufferRef CreateIndexBuffer(int32_t elementCount, const void* initialData, Effekseer::Backend::IndexBufferStrideType stride) override;

	Effekseer::Backend::TextureRef CreateTexture(const Effekseer::Backend::TextureParameter& param) override;

	Effekseer::Backend::TextureRef CreateRenderTexture(const Effekseer::Backend::RenderTextureParameter& param) override;

	Effekseer::Backend::TextureRef CreateDepthTexture(const Effekseer::Backend::DepthTextureParameter& param) override;

	Effekseer::Backend::UniformBufferRef CreateUniformBuffer(int32_t size, const void* initialData) override;

	Effekseer::Backend::VertexLayoutRef CreateVertexLayout(const Effekseer::Backend::VertexLayoutElement* elements, int32_t elementCount) override;

	Effekseer::Backend::RenderPassRef CreateRenderPass(Effekseer::FixedSizeVector<Effekseer::Backend::TextureRef, Effekseer::Backend::RenderTargetMax>& textures, Effekseer::Backend::TextureRef& depthTexture) override;

	Effekseer::Backend::ShaderRef CreateShaderFromKey(const char* key) override;

	Effekseer::Backend::ShaderRef CreateShaderFromCodes(const char* vsCode, const char* psCode, Effekseer::Backend::UniformLayoutRef layout) override;

	Effekseer::Backend::PipelineStateRef CreatePipelineState(const Effekseer::Backend::PipelineStateParameter& param) override;

	void Draw(const Effekseer::Backend::DrawParameter& drawParam) override;

	void BeginRenderPass(Effekseer::Backend::RenderPassRef& renderPass, bool isColorCleared, bool isDepthCleared, Effekseer::Color clearColor) override;

	void EndRenderPass() override;

	bool UpdateUniformBuffer(Effekseer::Backend::UniformBufferRef& buffer, int32_t size, int32_t offset, const void* data) override;

	std::string GetDeviceName() const override
	{
		return "OpenGL";
	}

	Effekseer::Backend::TextureRef CreateTexture(bgfx_texture_handle_t buffer, bool hasMipmap, const std::function<void()>& onDisposed);
};

} // namespace Backend

} // namespace EffekseerRendererBGFX
