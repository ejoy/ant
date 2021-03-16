
#ifndef __EFFEKSEERRENDERER_VERTEXBUFFER_BASE_H__
#define __EFFEKSEERRENDERER_VERTEXBUFFER_BASE_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include <Effekseer.h>
#include <assert.h>
#include <string.h>

//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
namespace EffekseerRenderer
{
//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
class VertexBufferBase
{
protected:
	bool m_isDynamic;
	int m_size;
	int m_offset;
	uint8_t* m_resource;
	bool m_isLock;

public:
	VertexBufferBase(int size, bool isDynamic);
	virtual ~VertexBufferBase();

	virtual void Lock() = 0;
	virtual bool RingBufferLock(int32_t size, int32_t& offset, void*& data, int32_t alignment) = 0;

	/**
		@brief	try lock as a ring buffer. if failed, it does't lock it.
	*/
	virtual bool TryRingBufferLock(int32_t size, int32_t& offset, void*& data, int32_t alignment) = 0;

	virtual void Unlock() = 0;
	virtual void Push(const void* buffer, int size);
	virtual int GetMaxSize() const;
	virtual int GetSize() const;
	virtual void* GetBufferDirect(int size);
};

//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
} // namespace EffekseerRenderer
//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
#endif // __EFFEKSEERRENDERER_VERTEXBUFFER_BASE_H__