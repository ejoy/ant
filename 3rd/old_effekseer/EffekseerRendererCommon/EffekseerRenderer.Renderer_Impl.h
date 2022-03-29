#ifndef __EFFEKSEERRENDERER_RENDERER_IMPL_H__
#define __EFFEKSEERRENDERER_RENDERER_IMPL_H__

#include <Effekseer.h>

#include "EffekseerRenderer.Renderer.h"

namespace EffekseerRenderer
{

class Renderer::Impl final : public ::Effekseer::SIMD::AlignedAllocationPolicy<16>
{
private:
	::Effekseer::SIMD::Mat44f projectionMat_;
	::Effekseer::SIMD::Mat44f cameraMat_;
	::Effekseer::SIMD::Mat44f cameraProjMat_;

	::Effekseer::SIMD::Vec3f cameraPosition_{0.0f, 0.0f, 0.0f};
	::Effekseer::SIMD::Vec3f cameraFrontDirection_{0.0f, 0.0f, 1.0f};

	::Effekseer::SIMD::Vec3f lightDirection_ = ::Effekseer::SIMD::Vec3f(1.0f, 1.0f, 1.0f);
	::Effekseer::Color lightColor_ = ::Effekseer::Color(255, 255, 255, 255);
	::Effekseer::Color lightAmbient_ = ::Effekseer::Color(40, 40, 40, 255);

	UVStyle textureUVStyle = UVStyle::Normal;
	UVStyle backgroundTextureUVStyle = UVStyle::Normal;
	float time_ = 0.0f;

	Effekseer::RenderMode renderMode_ = Effekseer::RenderMode::Normal;

	::Effekseer::Backend::TextureRef whiteProxyTexture_;
	::Effekseer::Backend::TextureRef normalProxyTexture_;

	::Effekseer::Backend::TextureRef backgroundTexture_;
	::Effekseer::Backend::TextureRef depthTexture_;
	DepthReconstructionParameter reconstructionParam_;

	void SetCameraParameterInternal(const ::Effekseer::SIMD::Vec3f& front, const ::Effekseer::SIMD::Vec3f& position);

public:
	int32_t drawcallCount = 0;
	int32_t drawvertexCount = 0;
	bool isRenderModeValid = true;
	bool isSoftParticleEnabled = false;
	bool isDepthReversed = false;

	Effekseer::RefPtr<Effekseer::RenderingUserData> CurrentRenderingUserData;
	void* CurrentHandleUserData = nullptr;

	Impl() = default;
	~Impl();

	::Effekseer::Vector3D GetLightDirection() const;

	void SetLightDirection(const ::Effekseer::Vector3D& direction);

	const ::Effekseer::Color& GetLightColor() const;

	void SetLightColor(const ::Effekseer::Color& color);

	const ::Effekseer::Color& GetLightAmbientColor() const;

	void SetLightAmbientColor(const ::Effekseer::Color& color);

	void CalculateCameraProjectionMatrix();

	::Effekseer::Matrix44 GetProjectionMatrix() const;

	void SetProjectionMatrix(const ::Effekseer::Matrix44& mat);

	::Effekseer::Matrix44 GetCameraMatrix() const;

	void SetCameraMatrix(const ::Effekseer::Matrix44& mat);

	::Effekseer::Vector3D GetCameraFrontDirection() const;

	::Effekseer::Vector3D GetCameraPosition() const;

	void SetCameraParameter(const ::Effekseer::Vector3D& front, const ::Effekseer::Vector3D& position);

	::Effekseer::Matrix44 GetCameraProjectionMatrix() const;

	void CreateProxyTextures(Renderer* renderer);

	void DeleteProxyTextures(Renderer* renderer);

	::Effekseer::Backend::TextureRef GetProxyTexture(EffekseerRenderer::ProxyTextureType type);

	UVStyle GetTextureUVStyle() const;

	void SetTextureUVStyle(UVStyle style);

	UVStyle GetBackgroundTextureUVStyle() const;

	void SetBackgroundTextureUVStyle(UVStyle style);

	int32_t GetDrawCallCount() const;

	int32_t GetDrawVertexCount() const;

	void ResetDrawCallCount();

	void ResetDrawVertexCount();

	float GetTime() const;

	void SetTime(float time);

	Effekseer::RenderMode GetRenderMode() const;

	void SetRenderMode(Effekseer::RenderMode renderMode);

	const ::Effekseer::Backend::TextureRef& GetBackground();

	void SetBackground(::Effekseer::Backend::TextureRef texture);

	void GetDepth(::Effekseer::Backend::TextureRef& texture, DepthReconstructionParameter& reconstructionParam);

	void SetDepth(::Effekseer::Backend::TextureRef texture, const DepthReconstructionParameter& reconstructionParam);
};

} // namespace EffekseerRenderer

#endif