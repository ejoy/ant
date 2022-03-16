#include "EffekseerRendererBGFX.VertexBuffer.h"

namespace EffekseerRendererBGFX {

VertexBuffer::VertexBuffer(int size, bool isDynamic, const bgfx_vertex_layout_t& layout)
	: VertexBufferBase(size, isDynamic)
	, m_vertexRingStart(0)
	, m_vertexRingOffset(0)
	, m_ringBufferLock(false)
	, m_layout{ layout }
{
}

VertexBuffer::~VertexBuffer()
{
}

VertexBuffer* VertexBuffer::Create(int size, bool isDynamic, const bgfx_vertex_layout_t& layout)
{
	return new VertexBuffer(size, isDynamic, layout);
}

bgfx_transient_vertex_buffer_t* VertexBuffer::GetInterface()
{
	return &m_transient_vertex_buffer;
}

void VertexBuffer::Lock()
{
	assert(!m_isLock);
	assert(!m_ringBufferLock);
	m_isLock = true;
	m_offset = 0;
	m_vertexRingStart = 0;
}

bool VertexBuffer::RingBufferLock(int32_t size, int32_t& offset, void*& data, int32_t alignment)
{
	assert(!m_isLock);
	assert(!m_ringBufferLock);
	assert(m_isDynamic);

	BGFX(alloc_transient_vertex_buffer)(&m_transient_vertex_buffer, size / m_layout.stride, &m_layout);
	data = m_transient_vertex_buffer.data;
	m_ringBufferLock = true;
	return true;
}

bool VertexBuffer::TryRingBufferLock(int32_t size, int32_t& offset, void*& data, int32_t alignment)
{
	if ((int32_t)m_vertexRingOffset + size > m_size)
		return false;

	return RingBufferLock(size, offset, data, alignment);
}

void VertexBuffer::Unlock()
{
	assert(m_isLock || m_ringBufferLock);
	m_resource = nullptr;
	m_isLock = false;
	m_ringBufferLock = false;
}

bool VertexBuffer::IsValid()
{
	return m_transient_vertex_buffer.size > 0;
}

int VertexBuffer::GetSize() const
{
	return m_transient_vertex_buffer.size;
}

namespace Backend
{
	Effekseer::Backend::VertexBufferRef VertexBuffer::Create(int size, const bgfx_vertex_layout_t& layout, const void* initialData, bool isDynamic)
	{
		return Effekseer::MakeRefPtr<VertexBuffer>(size, layout, initialData, isDynamic);
	}

	VertexBuffer::VertexBuffer(int size, const bgfx_vertex_layout_t& layout,
		const void* initialData, bool isDynamic)
		: m_size{ size }
		, m_is_dynamic{ isDynamic }
	{
		if (initialData) {
			m_buffer = BGFX(create_dynamic_vertex_buffer_mem)(
				BGFX(copy)(initialData, m_size),
				&layout,
				BGFX_BUFFER_NONE
				);
		} else {
			m_buffer = BGFX(create_dynamic_vertex_buffer)(size, &layout,
				BGFX_BUFFER_NONE);
		}
	}

	VertexBuffer::~VertexBuffer()
	{
		Deallocate();
	}
	
	bool VertexBuffer::Allocate(int32_t size, bool isDynamic)
	{
		return true;
	}

	void VertexBuffer::Deallocate()
	{
		BGFX(destroy_dynamic_vertex_buffer)(m_buffer);
	}

	bool VertexBuffer::Init(int32_t size, bool isDynamic)
	{
		return true;
	}

	void VertexBuffer::UpdateData(const void* src, int32_t size, int32_t offset)
	{
		BGFX(update_dynamic_vertex_buffer)(m_buffer, offset, BGFX(copy)(src, size));
	}
}
} // namespace EffekseerRendererBGFX
