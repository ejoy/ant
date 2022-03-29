#include "EffekseerRenderer.Renderer_Impl.h"
#include "EffekseerRenderer.Renderer.h"
#include <iostream>

namespace EffekseerRenderer
{

Renderer::Impl::~Impl()
{
}

void Renderer::Impl::SetCameraParameterInternal(const ::Effekseer::SIMD::Vec3f& front, const ::Effekseer::SIMD::Vec3f& position)
{
	cameraPosition_ = position;

	// To optimize particle, cameraFontDirection_ is normalized
	const auto length = front.GetLength();
	const auto eps = 0.0001f;
	if (length > eps)
	{
		cameraFrontDirection_ = front / length;
	}
	else
	{
		std::cout << "Warning : cameraFrontDirection is too small." << std::endl;
		cameraFrontDirection_ = ::Effekseer::SIMD::Vec3f{0.0f, 0.0f, 1.0f};
	}
}

::Effekseer::Vector3D Renderer::Impl::GetLightDirection() const
{
	return ToStruct(lightDirection_);
}

void Renderer::Impl::SetLightDirection(const ::Effekseer::Vector3D& direction)
{
	lightDirection_ = direction;
}

const ::Effekseer::Color& Renderer::Impl::GetLightColor() const
{
	return lightColor_;
}

void Renderer::Impl::SetLightColor(const ::Effekseer::Color& color)
{
	lightColor_ = color;
}

const ::Effekseer::Color& Renderer::Impl::GetLightAmbientColor() const
{
	return lightAmbient_;
}

void Renderer::Impl::SetLightAmbientColor(const ::Effekseer::Color& color)
{
	lightAmbient_ = color;
}

void Renderer::Impl::CalculateCameraProjectionMatrix()
{
	cameraProjMat_ = cameraMat_ * projectionMat_;
}

::Effekseer::Matrix44 Renderer::Impl::GetProjectionMatrix() const
{
	return ToStruct(projectionMat_);
}

void Renderer::Impl::SetProjectionMatrix(const ::Effekseer::Matrix44& mat)
{
	projectionMat_ = mat;
}

::Effekseer::Matrix44 Renderer::Impl::GetCameraMatrix() const
{
	return ToStruct(cameraMat_);
}

void Renderer::Impl::SetCameraMatrix(const ::Effekseer::Matrix44& mat)
{
	const auto f = ::Effekseer::SIMD::Vec3f(mat.Values[0][2], mat.Values[1][2], mat.Values[2][2]);
	const auto r = ::Effekseer::SIMD::Vec3f(mat.Values[0][0], mat.Values[1][0], mat.Values[2][0]);
	const auto u = ::Effekseer::SIMD::Vec3f(mat.Values[0][1], mat.Values[1][1], mat.Values[2][1]);
	const auto localPos = ::Effekseer::SIMD::Vec3f(-mat.Values[3][0], -mat.Values[3][1], -mat.Values[3][2]);

	const auto cameraPosition = r * localPos.GetX() + u * localPos.GetY() + f * localPos.GetZ();

	SetCameraParameterInternal(f, cameraPosition);
	cameraMat_ = mat;
}

::Effekseer::Matrix44 Renderer::Impl::GetCameraProjectionMatrix() const
{
	return ToStruct(cameraProjMat_);
}

::Effekseer::Vector3D Renderer::Impl::GetCameraFrontDirection() const
{
	return ToStruct(cameraFrontDirection_);
}

::Effekseer::Vector3D Renderer::Impl::GetCameraPosition() const
{
	return ToStruct(cameraPosition_);
}

void Renderer::Impl::SetCameraParameter(const ::Effekseer::Vector3D& front, const ::Effekseer::Vector3D& position)
{
	SetCameraParameterInternal(front, position);
}

void Renderer::Impl::CreateProxyTextures(Renderer* renderer)
{
	whiteProxyTexture_ = renderer->CreateProxyTexture(::EffekseerRenderer::ProxyTextureType::White);
	normalProxyTexture_ = renderer->CreateProxyTexture(::EffekseerRenderer::ProxyTextureType::Normal);
}

void Renderer::Impl::DeleteProxyTextures(Renderer* renderer)
{
	renderer->DeleteProxyTexture(whiteProxyTexture_);
	renderer->DeleteProxyTexture(normalProxyTexture_);
	whiteProxyTexture_ = nullptr;
	normalProxyTexture_ = nullptr;
}

::Effekseer::Backend::TextureRef Renderer::Impl::GetProxyTexture(EffekseerRenderer::ProxyTextureType type)
{
	if (type == EffekseerRenderer::ProxyTextureType::White)
		return whiteProxyTexture_;
	if (type == EffekseerRenderer::ProxyTextureType::Normal)
		return normalProxyTexture_;
	return nullptr;
}

UVStyle Renderer::Impl::GetTextureUVStyle() const
{
	return textureUVStyle;
}

void Renderer::Impl::SetTextureUVStyle(UVStyle style)
{
	textureUVStyle = style;
}

UVStyle Renderer::Impl::GetBackgroundTextureUVStyle() const
{
	return backgroundTextureUVStyle;
}

void Renderer::Impl::SetBackgroundTextureUVStyle(UVStyle style)
{
	backgroundTextureUVStyle = style;
}

int32_t Renderer::Impl::GetDrawCallCount() const
{
	return drawcallCount;
}

int32_t Renderer::Impl::GetDrawVertexCount() const
{
	return drawvertexCount;
}

void Renderer::Impl::ResetDrawCallCount()
{
	drawcallCount = 0;
}

void Renderer::Impl::ResetDrawVertexCount()
{
	drawvertexCount = 0;
}

float Renderer::Impl::GetTime() const
{
	return time_;
}

void Renderer::Impl::SetTime(float time)
{
	time_ = time;
}

Effekseer::RenderMode Renderer::Impl::GetRenderMode() const
{
	if (!isRenderModeValid)
	{
		printf("RenderMode is not implemented.\n");
		return Effekseer::RenderMode::Normal;
	}

	return renderMode_;
}

void Renderer::Impl::SetRenderMode(Effekseer::RenderMode renderMode)
{
	renderMode_ = renderMode;
}

const ::Effekseer::Backend::TextureRef& Renderer::Impl::GetBackground()
{
	return backgroundTexture_;
}

void Renderer::Impl::SetBackground(::Effekseer::Backend::TextureRef texture)
{
	backgroundTexture_ = texture;
}

void Renderer::Impl::GetDepth(::Effekseer::Backend::TextureRef& texture, DepthReconstructionParameter& reconstructionParam)
{
	texture = depthTexture_;

	if (texture != nullptr)
	{
		reconstructionParam = reconstructionParam_;
	}
	else
	{
		// return far clip depth
		const auto projMat = GetProjectionMatrix();
		reconstructionParam.ProjectionMatrix33 = projMat.Values[2][2];
		reconstructionParam.ProjectionMatrix43 = projMat.Values[2][3];
		reconstructionParam.ProjectionMatrix34 = projMat.Values[3][2];
		reconstructionParam.ProjectionMatrix44 = projMat.Values[3][3];

		if (isDepthReversed)
		{
			reconstructionParam.DepthBufferScale = 0.0f;
			reconstructionParam.DepthBufferOffset = 0.0f;
		}
		else
		{

			reconstructionParam.DepthBufferScale = 0.0f;
			reconstructionParam.DepthBufferOffset = 1.0f;
		}
	}
}

void Renderer::Impl::SetDepth(::Effekseer::Backend::TextureRef texture, const DepthReconstructionParameter& reconstructionParam)
{
	depthTexture_ = texture;
	reconstructionParam_ = reconstructionParam;
}

} // namespace EffekseerRenderer