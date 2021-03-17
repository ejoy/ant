#include "EffekseerRendererBGFX.IndexBuffer.h"

namespace EffekseerRendererBGFX
{
IndexBuffer::IndexBuffer(bgfx_dynamic_index_buffer_handle_s buffer, int maxCount, bool isDynamic, int32_t stride)
	: IndexBufferBase(maxCount, isDynamic)
	, m_buffer(buffer)
{
	stride_ = stride;
	m_resource = new uint8_t[m_indexMaxCount * stride_];
}

IndexBuffer::~IndexBuffer()
{
	delete[] m_resource;
	BGFX(destroy_dynamic_index_buffer)(m_buffer);
}

IndexBuffer* IndexBuffer::Create(int maxCount, bool isDynamic, int32_t stride)
{
	uint16_t flags = 0
		| ((stride == 4) ? BGFX_BUFFER_INDEX32 : 0);
	auto ib = BGFX(create_dynamic_index_buffer)(maxCount, flags);

	return new IndexBuffer(ib, maxCount, isDynamic, stride);
}

void IndexBuffer::Lock()
{
	assert(!m_isLock);

	m_isLock = true;
	m_indexCount = 0;
}

void IndexBuffer::Unlock()
{
	assert(m_isLock);
	BGFX(update_dynamic_index_buffer)(m_buffer, 0, BGFX(copy)(m_resource, m_indexCount * stride_));
	m_isLock = false;
}

bool IndexBuffer::IsValid()
{
	return BGFX_HANDLE_IS_VALID(m_buffer);
}

} // namespace EffekseerRendererBGFX
