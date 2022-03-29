
#include "EffekseerRenderer.Renderer.h"
#include "EffekseerRenderer.Renderer_Impl.h"
#include <Effekseer.h>
#include <assert.h>

namespace EffekseerRenderer
{

Renderer::Renderer()
	: impl(new Impl())
{
}

Renderer::~Renderer()
{
}

Renderer::Impl* Renderer::GetImpl()
{
	return impl.get();
}

::Effekseer::Vector3D Renderer::GetLightDirection() const
{
	return impl->GetLightDirection();
}

void Renderer::SetLightDirection(const ::Effekseer::Vector3D& direction)
{
	impl->SetLightDirection(direction);
}

const ::Effekseer::Color& Renderer::GetLightColor() const
{
	return impl->GetLightColor();
}

void Renderer::SetLightColor(const ::Effekseer::Color& color)
{
	impl->SetLightColor(color);
}

const ::Effekseer::Color& Renderer::GetLightAmbientColor() const
{
	return impl->GetLightAmbientColor();
}

void Renderer::SetLightAmbientColor(const ::Effekseer::Color& color)
{
	impl->SetLightAmbientColor(color);
}

::Effekseer::Matrix44 Renderer::GetProjectionMatrix() const
{
	return impl->GetProjectionMatrix();
}

void Renderer::SetProjectionMatrix(const ::Effekseer::Matrix44& mat)
{
	impl->SetProjectionMatrix(mat);
}

::Effekseer::Matrix44 Renderer::GetCameraMatrix() const
{
	return impl->GetCameraMatrix();
}

void Renderer::SetCameraMatrix(const ::Effekseer::Matrix44& mat)
{
	impl->SetCameraMatrix(mat);
}

::Effekseer::Matrix44 Renderer::GetCameraProjectionMatrix() const
{
	return impl->GetCameraProjectionMatrix();
}

::Effekseer::Vector3D Renderer::GetCameraFrontDirection() const
{
	return impl->GetCameraFrontDirection();
}

::Effekseer::Vector3D Renderer::GetCameraPosition() const
{
	return impl->GetCameraPosition();
}

void Renderer::SetCameraParameter(const ::Effekseer::Vector3D& front, const ::Effekseer::Vector3D& position)
{
	impl->SetCameraParameter(front, position);
}

int32_t Renderer::GetDrawCallCount() const
{
	return impl->GetDrawCallCount();
}

int32_t Renderer::GetDrawVertexCount() const
{
	return impl->GetDrawVertexCount();
}

void Renderer::ResetDrawCallCount()
{
	impl->ResetDrawCallCount();
}

void Renderer::ResetDrawVertexCount()
{
	impl->ResetDrawVertexCount();
}

Effekseer::RenderMode Renderer::GetRenderMode() const
{
	return impl->GetRenderMode();
}

void Renderer::SetRenderMode(Effekseer::RenderMode renderMode)
{
	impl->SetRenderMode(renderMode);
}

UVStyle Renderer::GetTextureUVStyle() const
{
	return impl->GetTextureUVStyle();
}

void Renderer::SetTextureUVStyle(UVStyle style)
{
	impl->SetTextureUVStyle(style);
}

UVStyle Renderer::GetBackgroundTextureUVStyle() const
{
	return impl->GetBackgroundTextureUVStyle();
}

void Renderer::SetBackgroundTextureUVStyle(UVStyle style)
{
	impl->SetBackgroundTextureUVStyle(style);
}

float Renderer::GetTime() const
{
	return impl->GetTime();
}

void Renderer::SetTime(float time)
{
	impl->SetTime(time);
}

const ::Effekseer::Backend::TextureRef& Renderer::GetBackground()
{
	return impl->GetBackground();
}

void Renderer::SetBackground(::Effekseer::Backend::TextureRef texture)
{
	impl->SetBackground(texture);
}

::Effekseer::Backend::TextureRef Renderer::CreateProxyTexture(EffekseerRenderer::ProxyTextureType type)
{
	std::array<uint8_t, 4> buf;

	if (type == EffekseerRenderer::ProxyTextureType::White)
	{
		buf = {255, 255, 255, 255};
	}
	else if (type == EffekseerRenderer::ProxyTextureType::Normal)
	{
		buf = {127, 127, 255, 255};
	}
	else
	{
		assert(0);
	}

	Effekseer::Backend::TextureParameter param;
	param.Format = Effekseer::Backend::TextureFormatType::R8G8B8A8_UNORM;
	param.Size = {1, 1};
	param.GenerateMipmap = false;
	param.InitialData.assign(buf.begin(), buf.end());
	return GetGraphicsDevice()->CreateTexture(param);
}

void Renderer::DeleteProxyTexture(::Effekseer::Backend::TextureRef& texture)
{
	texture.Reset();
}

void Renderer::GetDepth(::Effekseer::Backend::TextureRef& texture, DepthReconstructionParameter& reconstructionParam)
{
	impl->GetDepth(texture, reconstructionParam);
}

void Renderer::SetDepth(::Effekseer::Backend::TextureRef texture, const DepthReconstructionParameter& reconstructionParam)
{
	impl->SetDepth(texture, reconstructionParam);
}

Effekseer::Backend::GraphicsDeviceRef Renderer::GetGraphicsDevice() const
{
	return nullptr;
}

} // namespace EffekseerRenderer