
#ifndef __EFFEKSEERRENDERER_INDEXBUFFER_BASE_H__
#define __EFFEKSEERRENDERER_INDEXBUFFER_BASE_H__

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
class IndexBufferBase
{
protected:
	int m_indexMaxCount;
	int m_indexCount;
	bool m_isDynamic;
	bool m_isLock;
	uint8_t* m_resource;
	int32_t stride_ = 2;

public:
	IndexBufferBase(int maxCount, bool isDynamic);
	virtual ~IndexBufferBase();

	virtual void Lock() = 0;
	virtual void Unlock() = 0;
	void Push(const void* buffer, int count);
	int GetCount() const;
	int GetMaxCount() const;
	void* GetBufferDirect(int count);
};

//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
} // namespace EffekseerRenderer
//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
#endif // __EFFEKSEERRENDERER_INDEXBUFFER_BASE_H__