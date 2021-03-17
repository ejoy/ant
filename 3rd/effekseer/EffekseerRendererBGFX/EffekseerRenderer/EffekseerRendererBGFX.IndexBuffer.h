#pragma once
#include "../../EffekseerRendererCommon/EffekseerRenderer.IndexBufferBase.h"
#include "EffekseerRendererBGFX.RendererImplemented.h"

namespace EffekseerRendererBGFX
{
class IndexBuffer : public ::EffekseerRenderer::IndexBufferBase
{
private:
	bgfx_dynamic_index_buffer_handle_s/*bgfx::DynamicIndexBufferHandle*/ m_buffer/*{ BGFX_INVALID_HANDLE }*/;
	IndexBuffer(bgfx_dynamic_index_buffer_handle_s buffer, int maxCount, bool isDynamic, int32_t stride);

public:
	virtual ~IndexBuffer();
	static IndexBuffer* Create(int maxCount, bool isDynamic, int32_t stride);
	bgfx_dynamic_index_buffer_handle_s GetInterface() { return m_buffer; }
	void Lock() override;
	void Unlock() override;
	bool IsValid();
	int32_t GetStride() const { return stride_; }
};

} // namespace EffekseerRendererBGFX
