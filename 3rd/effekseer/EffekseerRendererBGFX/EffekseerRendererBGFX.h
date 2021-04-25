#pragma once

#include <Effekseer.h>
#include <bgfx/c99/bgfx.h>

namespace Effekseer
{
namespace Backend
{
class VertexBuffer;
class IndexBuffer;
class GraphicsDevice;
} // namespace Backend
} // namespace Effekseer

namespace EffekseerRenderer
{
class Renderer;
using RendererRef = ::Effekseer::RefPtr<Renderer>;
class DistortingCallback
{
public:
	DistortingCallback()
	{
	}
	virtual ~DistortingCallback()
	{
	}

	virtual bool OnDistorting(Renderer* renderer)
	{
		return false;
	}
};

enum class UVStyle
{
	Normal,
	VerticalFlipped,
};

enum class ProxyTextureType
{
	White,
	Normal,
};

class GraphicsDevice : public ::Effekseer::IReference
{
public:
	GraphicsDevice() = default;
	virtual ~GraphicsDevice() = default;
};

class CommandList : public ::Effekseer::IReference
{
public:
	CommandList() = default;
	virtual ~CommandList() = default;
};

class SingleFrameMemoryPool : public ::Effekseer::IReference
{
public:
	SingleFrameMemoryPool() = default;
	virtual ~SingleFrameMemoryPool() = default;
	virtual void NewFrame() {}
};

struct DepthReconstructionParameter
{
	float DepthBufferScale = 1.0f;
	float DepthBufferOffset = 0.0f;
	float ProjectionMatrix33 = 0.0f;
	float ProjectionMatrix34 = 0.0f;
	float ProjectionMatrix43 = 0.0f;
	float ProjectionMatrix44 = 0.0f;
};

class Renderer : public ::Effekseer::IReference
{
protected:
	Renderer();
	virtual ~Renderer();

	class Impl;
	std::unique_ptr<Impl> impl;

public:
	Impl* GetImpl();
	virtual void OnLostDevice() = 0;
	virtual void OnResetDevice() = 0;
	virtual void SetRestorationOfStatesFlag(bool flag) = 0;
	virtual bool BeginRendering() = 0;
	virtual bool EndRendering() = 0;
	virtual ::Effekseer::Vector3D GetLightDirection() const;
	virtual void SetLightDirection(const ::Effekseer::Vector3D& direction);
	virtual const ::Effekseer::Color& GetLightColor() const;
	virtual void SetLightColor(const ::Effekseer::Color& color);
	virtual const ::Effekseer::Color& GetLightAmbientColor() const;
	virtual void SetLightAmbientColor(const ::Effekseer::Color& color);
	virtual int32_t GetSquareMaxCount() const = 0;
	virtual ::Effekseer::Matrix44 GetProjectionMatrix() const;
	virtual void SetProjectionMatrix(const ::Effekseer::Matrix44& mat);
	virtual ::Effekseer::Matrix44 GetCameraMatrix() const;
	virtual void SetCameraMatrix(const ::Effekseer::Matrix44& mat);
	virtual ::Effekseer::Matrix44 GetCameraProjectionMatrix() const;
	virtual ::Effekseer::Vector3D GetCameraFrontDirection() const;
	virtual ::Effekseer::Vector3D GetCameraPosition() const;
	virtual void SetCameraParameter(const ::Effekseer::Vector3D& front, const ::Effekseer::Vector3D& position);
	virtual ::Effekseer::SpriteRendererRef CreateSpriteRenderer() = 0;
	virtual ::Effekseer::RibbonRendererRef CreateRibbonRenderer() = 0;
	virtual ::Effekseer::RingRendererRef CreateRingRenderer() = 0;
	virtual ::Effekseer::ModelRendererRef CreateModelRenderer() = 0;
	virtual ::Effekseer::TrackRendererRef CreateTrackRenderer() = 0;
	virtual ::Effekseer::TextureLoaderRef CreateTextureLoader(::Effekseer::FileInterface* fileInterface = nullptr) = 0;
	virtual ::Effekseer::ModelLoaderRef CreateModelLoader(::Effekseer::FileInterface* fileInterface = nullptr) = 0;
	virtual ::Effekseer::MaterialLoaderRef CreateMaterialLoader(::Effekseer::FileInterface* fileInterface = nullptr) = 0;
	virtual void ResetRenderState() = 0;
	virtual DistortingCallback* GetDistortingCallback() = 0;
	virtual void SetDistortingCallback(DistortingCallback* callback) = 0;
	virtual int32_t GetDrawCallCount() const;
	virtual int32_t GetDrawVertexCount() const;
	virtual void ResetDrawCallCount();
	virtual void ResetDrawVertexCount();
	virtual Effekseer::RenderMode GetRenderMode() const;
	virtual void SetRenderMode(Effekseer::RenderMode renderMode);
	virtual UVStyle GetTextureUVStyle() const;
	virtual void SetTextureUVStyle(UVStyle style);
	virtual UVStyle GetBackgroundTextureUVStyle() const;
	virtual void SetBackgroundTextureUVStyle(UVStyle style);
	virtual float GetTime() const;
	virtual void SetTime(float time);
	virtual void SetCommandList(CommandList* commandList)
	{
	}
	virtual const ::Effekseer::Backend::TextureRef& GetBackground();
	virtual void SetBackground(::Effekseer::Backend::TextureRef texture);
	virtual ::Effekseer::Backend::TextureRef CreateProxyTexture(ProxyTextureType type);
	virtual void DeleteProxyTexture(Effekseer::Backend::TextureRef& texture);
	virtual void GetDepth(::Effekseer::Backend::TextureRef& texture, DepthReconstructionParameter& reconstructionParam);
	virtual void SetDepth(::Effekseer::Backend::TextureRef texture, const DepthReconstructionParameter& reconstructionParam);

	virtual Effekseer::Backend::GraphicsDeviceRef GetGraphicsDevice() const;
};

} // namespace EffekseerRenderer

namespace EffekseerRendererBGFX
{

::Effekseer::Backend::GraphicsDeviceRef CreateGraphicsDevice(/*OpenGLDeviceType deviceType, bool isExtensionsEnabled = true*/);

::Effekseer::TextureLoaderRef CreateTextureLoader(
	Effekseer::Backend::GraphicsDeviceRef graphicsDevice,
	::Effekseer::FileInterface* fileInterface = nullptr,
	::Effekseer::ColorSpaceType colorSpaceType = ::Effekseer::ColorSpaceType::Gamma);

::Effekseer::ModelLoaderRef CreateModelLoader(::Effekseer::FileInterface* fileInterface = nullptr/*, OpenGLDeviceType deviceType = OpenGLDeviceType::OpenGL2*/);

::Effekseer::MaterialLoaderRef CreateMaterialLoader(Effekseer::Backend::GraphicsDeviceRef graphicsDevice,
												  ::Effekseer::FileInterface* fileInterface = nullptr);

Effekseer::Backend::TextureRef CreateTexture(Effekseer::Backend::GraphicsDeviceRef graphicsDevice, bgfx_texture_handle_t buffer, bool hasMipmap, const std::function<void()>& onDisposed);


// class Renderer;
// using RendererRef = ::Effekseer::RefPtr<Renderer>;
// 
// class Renderer : public ::EffekseerRenderer::Renderer
// {
// protected:
// 	Renderer()
// 	{
// 	}
// 	virtual ~Renderer()
// 	{
// 	}
// public:
// 	static RendererRef Create(int32_t squareMaxCount/*, OpenGLDeviceType deviceType = OpenGLDeviceType::OpenGL2, bool isExtensionsEnabled = true*/);
// 	static RendererRef Create(Effekseer::Backend::GraphicsDeviceRef graphicsDevice, int32_t squareMaxCount);
// 
// 	virtual int32_t GetSquareMaxCount() const = 0;
// 	virtual void SetSquareMaxCount(int32_t count) = 0;
// 	virtual void SetBackground(bgfx_texture_handle_t background, bool hasMipmap = false) = 0;
// 	virtual bool IsVertexArrayObjectSupported() const = 0;
// };

} // namespace EffekseerRendererBGFX
