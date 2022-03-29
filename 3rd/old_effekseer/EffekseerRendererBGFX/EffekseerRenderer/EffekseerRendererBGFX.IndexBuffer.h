#pragma once
#include "../../EffekseerRendererCommon/EffekseerRenderer.IndexBufferBase.h"
#include "EffekseerRendererBGFX.RendererImplemented.h"

namespace EffekseerRendererBGFX
{
class IndexBuffer : public ::EffekseerRenderer::IndexBufferBase
{
private:
	bgfx_dynamic_index_buffer_handle_s m_buffer;
	IndexBuffer(bgfx_dynamic_index_buffer_handle_s buffer, int maxCount, bool isDynamic, int32_t stride);

public:
	virtual ~IndexBuffer();
	static IndexBuffer* Create(int maxCount, bool isDynamic, int32_t stride);
	bgfx_dynamic_index_buffer_handle_s GetInterface() { return m_buffer; }
	void Lock() override;
	void Unlock() override;
	bool IsValid();
	int32_t GetStride() const { return m_stride; }
};
namespace Backend
{
	class IndexBuffer : public Effekseer::Backend::IndexBuffer
	{
	private:
		bgfx_dynamic_index_buffer_handle_s m_buffer{ BGFX_INVALID_HANDLE };
		std::vector<uint8_t> m_resources;
		int32_t m_stride = 0;
		bool m_is_dynamic = false;
	public:
		static Effekseer::Backend::IndexBufferRef Create(int elementCount,
			Effekseer::Backend::IndexBufferStrideType strideType,
			const void* initialData = nullptr, bool isDynamic = false);
		IndexBuffer(int maxCount, Effekseer::Backend::IndexBufferStrideType stride, const void* initialData = nullptr, bool isDynamic = false);

		virtual ~IndexBuffer();
		bool Allocate(int32_t elementCount, int32_t stride);
		void Deallocate();
		bool Init(int32_t elementCount, int32_t stride);
		void UpdateData(const void* src, int32_t size, int32_t offset) override;
		bgfx_dynamic_index_buffer_handle_s GetInterface() { return m_buffer; }
	};
}
} // namespace EffekseerRendererBGFX
