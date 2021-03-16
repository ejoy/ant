#include "EffekseerRendererBGFX.VertexBuffer.h"

namespace EffekseerRendererBGFX {

VertexBuffer::VertexBuffer(int size, bool isDynamic, const bgfx_vertex_layout_t& layout)
	: VertexBufferBase(size, isDynamic)
	, m_vertexRingStart(0)
	, m_vertexRingOffset(0)
	, m_ringBufferLock(false)
{
	m_resource = new uint8_t[m_size];
	memset(m_resource, 0, (size_t)m_size);
	m_stride = layout.stride;
	m_buffer = BGFX(create_dynamic_vertex_buffer_mem)(
		BGFX(copy)(m_resource, m_size),
		&layout,
		BGFX_BUFFER_NONE
	);
}

VertexBuffer::~VertexBuffer()
{
	delete[] m_resource;
	BGFX(destroy_dynamic_vertex_buffer)(m_buffer);
}

VertexBuffer* VertexBuffer::Create(int size, bool isDynamic, const bgfx_vertex_layout_t& layout)
{
	return new VertexBuffer(size, isDynamic, layout);
}

bgfx_dynamic_vertex_buffer_handle_s VertexBuffer::GetInterface()
{
	return m_buffer;
}

void VertexBuffer::Lock()
{
	assert(!m_isLock);

	m_isLock = true;
	m_offset = 0;
	m_vertexRingStart = 0;
}

bool VertexBuffer::RingBufferLock(int32_t size, int32_t& offset, void*& data, int32_t alignment)
{
	assert(!m_isLock);
	assert(!m_ringBufferLock);
	assert(this->m_isDynamic);

	if (size > m_size)
		return false;

	m_vertexRingOffset = (m_vertexRingOffset + alignment - 1) / alignment * alignment;

#ifdef __ANDROID__
	if (true)
#else
	if ((int32_t)m_vertexRingOffset + size > m_size)
#endif
	{
		offset = 0;
		data = m_resource;
		m_vertexRingOffset = size;

		m_vertexRingStart = offset;
		m_offset = size;
	}
	else
	{
		offset = m_vertexRingOffset;
		data = m_resource;
		m_vertexRingOffset += size;

		m_vertexRingStart = offset;
		m_offset = size;
	}

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
	BGFX(update_dynamic_vertex_buffer)(m_buffer, m_vertexRingStart / m_stride, BGFX(copy)(m_resource, m_offset));
	if (m_isLock)
	{
		m_vertexRingOffset += m_offset;
	}

	m_isLock = false;
	m_ringBufferLock = false;
}

bool VertexBuffer::IsValid()
{
	return BGFX_HANDLE_IS_VALID(m_buffer);
}

} // namespace EffekseerRendererBGFX
