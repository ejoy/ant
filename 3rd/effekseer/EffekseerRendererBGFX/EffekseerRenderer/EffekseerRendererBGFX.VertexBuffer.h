#pragma once
#include "../../EffekseerRendererCommon/EffekseerRenderer.VertexBufferBase.h"
#include "EffekseerRendererBGFX.RendererImplemented.h"

namespace EffekseerRendererBGFX {
class VertexBuffer : public ::EffekseerRenderer::VertexBufferBase
{
private:
	bgfx_vertex_layout_t m_layout;
	//uint16_t m_stride;
	//bgfx_dynamic_vertex_buffer_handle_t m_buffer{ BGFX_INVALID_HANDLE };
	bgfx_transient_vertex_buffer_t m_transient_vertex_buffer;
	uint32_t m_vertexRingStart;
	uint32_t m_vertexRingOffset;
	bool m_ringBufferLock;
	VertexBuffer(int size, bool isDynamic, const bgfx_vertex_layout_t& layout);
public:
	virtual ~VertexBuffer();
	static VertexBuffer* Create(int size, bool isDynamic, const bgfx_vertex_layout_t& layout);
	//bgfx_dynamic_vertex_buffer_handle_t GetInterface();
	bgfx_transient_vertex_buffer_t* GetInterface();
	void Lock();
	bool RingBufferLock(int32_t size, int32_t& offset, void*& data, int32_t alignment) override;
	bool TryRingBufferLock(int32_t size, int32_t& offset, void*& data, int32_t alignment) override;
	void Unlock();
	bool IsValid();
	int GetSize() const override;
};
namespace Backend
{
	class VertexBuffer : public Effekseer::Backend::VertexBuffer
	{
	private:
		std::vector<uint8_t> m_resources;
		bgfx_dynamic_vertex_buffer_handle_t m_buffer{ BGFX_INVALID_HANDLE };
		int32_t m_size = 0;
		bool m_is_dynamic = false;
	public:
		VertexBuffer(int size, const bgfx_vertex_layout_t& layout,
			const void* initialData = nullptr, bool isDynamic = false);
		~VertexBuffer() override;
		static Effekseer::Backend::VertexBufferRef Create(int size, const bgfx_vertex_layout_t& layout, const void* initialData = nullptr, bool isDynamic = false);
		bool Allocate(int32_t size, bool isDynamic);
		void Deallocate();
		int32_t GetSize() { return m_size; }
		bool Init(int32_t size, bool isDynamic);
		void UpdateData(const void* src, int32_t size, int32_t offset) override;
		bgfx_dynamic_vertex_buffer_handle_t GetInterface() { return m_buffer; }
	};
}
} // namespace EffekseerRendererBGFX
