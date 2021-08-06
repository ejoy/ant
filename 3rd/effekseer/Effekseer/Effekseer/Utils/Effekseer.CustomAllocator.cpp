#include "Effekseer.CustomAllocator.h"

#if defined(__MINGW32__)
#include <malloc.h>
#endif

#include <cstdlib>
namespace Effekseer
{

void* EFK_STDCALL InternalMalloc(unsigned int size)
{
	return (void*)new char*[size];
}

void EFK_STDCALL InternalFree(void* p, unsigned int size)
{
	char* pData = (char*)p;
	delete[] pData;
}

void* EFK_STDCALL InternalAlignedMalloc(unsigned int size, unsigned int alignement)
{
#if defined(__EMSCRIPTEN__) && __EMSCRIPTEN_minor__ < 38
	return malloc(size);
#elif defined(_MSC_VER) || defined(__MINGW32__) || defined(__MINGW64__)
	return _mm_malloc(size, alignement);
#else
	void* ptr = nullptr;
	posix_memalign(&ptr, alignement, size);
	return ptr;
#endif
}

void EFK_STDCALL InternalAlignedFree(void* p, unsigned int size)
{
#if defined(__EMSCRIPTEN__) && __EMSCRIPTEN_minor__ < 38
	free(p);
#elif defined(_MSC_VER) || defined(__MINGW32__) || defined(__MINGW64__)
	_mm_free(p);
//#elif defined(__MINGW32__) || define(__MINGW64__)
//	return _aligned_free(p);
#else
	return free(p);
#endif
}

MallocFunc mallocFunc_ = InternalMalloc;

FreeFunc freeFunc_ = InternalFree;

AlignedMallocFunc alignedMallocFunc_ = InternalAlignedMalloc;

AlignedFreeFunc alignedFreeFunc_ = InternalAlignedFree;

MallocFunc GetMallocFunc()
{
	return mallocFunc_;
}

void SetMallocFunc(MallocFunc func)
{
	mallocFunc_ = func;
}

FreeFunc GetFreeFunc()
{
	return freeFunc_;
}

void SetFreeFunc(FreeFunc func)
{
	freeFunc_ = func;
}

AlignedMallocFunc GetAlignedMallocFunc()
{
	return alignedMallocFunc_;
}

void SetAlignedMallocFunc(AlignedMallocFunc func)
{
	alignedMallocFunc_ = func;
}

AlignedFreeFunc GetAlignedFreeFunc()
{
	return alignedFreeFunc_;
}

void SetAlignedFreeFunc(AlignedFreeFunc func)
{
	alignedFreeFunc_ = func;
}

} // namespace Effekseer
