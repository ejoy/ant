#include "EffekseerRendererBGFX.IndexBuffer.h"

namespace EffekseerRendererBGFX
{
IndexBuffer::IndexBuffer(bgfx_dynamic_index_buffer_handle_s buffer, int maxCount, bool isDynamic, int32_t stride)
	: IndexBufferBase(maxCount, isDynamic)
	, m_buffer(buffer)
{
	m_stride = stride;
	m_resource = new uint8_t[m_indexMaxCount * m_stride];
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
	auto ib = BGFX(create_dynamic_index_buffer)(maxCount * stride, flags);

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
	BGFX(update_dynamic_index_buffer)(m_buffer, 0, BGFX(copy)(m_resource, m_indexCount * m_stride));
	m_isLock = false;
}

bool IndexBuffer::IsValid()
{
	return BGFX_HANDLE_IS_VALID(m_buffer);
}
namespace Backend
{
	IndexBuffer::IndexBuffer(int count, Effekseer::Backend::IndexBufferStrideType strideType, const void* initialData, bool isDynamic)
		: m_is_dynamic{ isDynamic }
	{
		strideType_ = strideType;
		elementCount_ = count;
		m_stride = (strideType == Effekseer::Backend::IndexBufferStrideType::Stride4) ? 4 : 2;
		auto size = count * m_stride;
		m_resources.resize(size);
		uint16_t flags = 0
			| ((m_stride == 4) ? BGFX_BUFFER_INDEX32 : 0);
		if (initialData) {
			m_buffer = BGFX(create_dynamic_index_buffer_mem)(BGFX(copy)(initialData, size), flags);
		} else {
			m_buffer = BGFX(create_dynamic_index_buffer)(count, flags);
		}
	}

	IndexBuffer::~IndexBuffer()
	{
		Deallocate();
	}

	bool IndexBuffer::Allocate(int32_t elementCount, int32_t stride)
	{
		m_resources.resize(elementCount_ * m_stride);
		elementCount_ = elementCount;
		strideType_ = stride == 4 ? Effekseer::Backend::IndexBufferStrideType::Stride4
			: Effekseer::Backend::IndexBufferStrideType::Stride2;
		return true;
	}

	void IndexBuffer::Deallocate()
	{
		BGFX(destroy_dynamic_index_buffer)(m_buffer);
	}

	bool IndexBuffer::Init(int32_t elementCount, int32_t stride)
	{
		return true;
	}

	void IndexBuffer::UpdateData(const void* src, int32_t size, int32_t offset)
	{
		memcpy(m_resources.data() + offset, src, size);
		BGFX(update_dynamic_index_buffer)(m_buffer, 0, BGFX(copy)(m_resources.data(), elementCount_ * m_stride));
	}

	Effekseer::Backend::IndexBufferRef IndexBuffer::Create(int elementCount, Effekseer::Backend::IndexBufferStrideType strideType, const void* initialData, bool isDynamic)
	{
		return Effekseer::MakeRefPtr<IndexBuffer>(elementCount, strideType, initialData, isDynamic);
	}
}
} // namespace EffekseerRendererBGFX
