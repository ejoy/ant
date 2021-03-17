#pragma once
#include "../../EffekseerRendererCommon/EffekseerRenderer.RenderStateBase.h"
#include "../../EffekseerRendererCommon/EffekseerRenderer.StandardRenderer.h"
#include "EffekseerRendererBGFX.Base.h"
#include "EffekseerRendererBGFX.Renderer.h"
#include "GraphicsDevice.h"

extern "C" {
	extern bgfx_interface_vtbl_t* ibgfx();
}

#define BGFX(api) ibgfx()->api

namespace EffekseerRendererBGFX
{

using Vertex = EffekseerRenderer::SimpleVertex;
//using VertexDistortion = EffekseerRenderer::VertexDistortion;

struct RenderStateSet
{
	//GLboolean blend;
	//GLboolean cullFace;
	//GLboolean depthTest;
	//GLboolean depthWrite;
	//GLboolean texture;
	//GLint depthFunc;
	//GLint cullFaceMode;
	//GLint blendSrc;
	//GLint blendDst;
	//GLint blendEquation;
	//GLint vao;
	//GLint arrayBufferBinding;
	//GLint elementArrayBufferBinding;
	//std::array<GLint, ::Effekseer::TextureSlotMax> boundTextures;
};

class RendererImplemented;
using RendererImplementedRef = ::Effekseer::RefPtr<RendererImplemented>;

class RendererImplemented : public Renderer, public ::Effekseer::ReferenceObject
{
	friend class DeviceObject;

private:
	Backend::GraphicsDeviceRef graphicsDevice_ = nullptr;
	struct BGFXBuffer
	{
		VertexBuffer* m_vertexBuffer{ nullptr };
		IndexBuffer* m_indexBuffer{ nullptr };
		IndexBuffer* m_indexBufferForWireframe{ nullptr };
	};
	std::vector<BGFXBuffer> bgfx_buffer_;

	int32_t m_squareMaxCount;

	std::vector<Shader*> shaders_;
	Shader* currentShader = nullptr;

	EffekseerRenderer::StandardRenderer<RendererImplemented, Shader>* m_standardRenderer;

	::EffekseerRenderer::RenderStateBase* m_renderState;

	// for restoring states
	RenderStateSet m_originalState;

	bool m_restorationOfStates;

	EffekseerRenderer::DistortingCallback* m_distortingCallback;

	::Effekseer::Backend::TextureRef m_backgroundGL;

	// textures which are specified currently
	std::vector<::Effekseer::Backend::TextureRef> currentTextures_;

	int32_t indexBufferStride_ = 2;

	int32_t indexBufferCurrentStride_ = 0;

	//! because gleDrawElements has only index offset
	int32_t GetIndexSpriteCount() const;

public:
	RendererImplemented(int32_t squareMaxCount, Backend::GraphicsDeviceRef graphicsDevice);

	~RendererImplemented();

	void OnLostDevice() override {}
	void OnResetDevice() override {}

	bool Initialize();
	void SetRestorationOfStatesFlag(bool flag) override;
	bool BeginRendering() override;
	bool EndRendering() override;

	VertexBuffer* GetVertexBuffer();
	IndexBuffer* GetIndexBuffer();

	int32_t GetSquareMaxCount() const override;
	void SetSquareMaxCount(int32_t count) override;

	::EffekseerRenderer::RenderStateBase* GetRenderState();

	::Effekseer::SpriteRendererRef CreateSpriteRenderer() override;
	::Effekseer::RibbonRendererRef CreateRibbonRenderer() override;
	::Effekseer::RingRendererRef CreateRingRenderer() override;
	::Effekseer::ModelRendererRef CreateModelRenderer() override;
	::Effekseer::TrackRendererRef CreateTrackRenderer() override;
	::Effekseer::TextureLoaderRef CreateTextureLoader(::Effekseer::FileInterface* fileInterface = nullptr) override;
	::Effekseer::ModelLoaderRef CreateModelLoader(::Effekseer::FileInterface* fileInterface = nullptr) override;
	::Effekseer::MaterialLoaderRef CreateMaterialLoader(::Effekseer::FileInterface* fileInterface = nullptr) override;

	void SetBackground(bgfx_texture_handle_t background, bool hasMipmap) override;
	EffekseerRenderer::DistortingCallback* GetDistortingCallback() override;
	void SetDistortingCallback(EffekseerRenderer::DistortingCallback* callback) override;
	EffekseerRenderer::StandardRenderer<RendererImplemented, Shader>* GetStandardRenderer() { return m_standardRenderer; }

	void SetVertexBuffer(VertexBuffer* vertexBuffer, int32_t size);
	void SetIndexBuffer(IndexBuffer* indexBuffer);
	void SetVertexBuffer(const Effekseer::Backend::VertexBufferRef& vertexBuffer, int32_t size);
	void SetIndexBuffer(const Effekseer::Backend::IndexBufferRef& indexBuffer);
	void SetVertexArray(VertexArray* vertexArray);

	void SetLayout(Shader* shader);
	void DrawSprites(int32_t spriteCount, int32_t vertexOffset);
	void DrawPolygon(int32_t vertexCount, int32_t indexCount);
	void DrawPolygonInstanced(int32_t vertexCount, int32_t indexCount, int32_t instanceCount);

	Shader* GetShader(::EffekseerRenderer::RendererShaderType type) const;
	void BeginShader(Shader* shader);
	void EndShader(Shader* shader);

	void SetVertexBufferToShader(const void* data, int32_t size, int32_t dstOffset);
	void SetPixelBufferToShader(const void* data, int32_t size, int32_t dstOffset);
	void SetTextures(Shader* shader, Effekseer::Backend::TextureRef* textures, int32_t count);
	void ResetRenderState() override;

	const std::vector<::Effekseer::Backend::TextureRef>& GetCurrentTextures() const { return currentTextures_; }
	bool IsVertexArrayObjectSupported() const override;
	Backend::GraphicsDeviceRef& GetIntetnalGraphicsDevice() { return graphicsDevice_; }
	Effekseer::Backend::GraphicsDeviceRef GetGraphicsDevice() const override { return graphicsDevice_; }
	virtual int GetRef() override { return ::Effekseer::ReferenceObject::GetRef(); }
	virtual int AddRef() override { return ::Effekseer::ReferenceObject::AddRef(); }
	virtual int Release() override { return ::Effekseer::ReferenceObject::Release(); }

private:
	void GenerateIndexData();

	template <typename T>
	void GenerateIndexDataStride();
};

void AssignPixelConstantBuffer(Shader* shader);

void AssignDistortionPixelConstantBuffer(Shader* shader);

} // namespace EffekseerRendererBGFX
