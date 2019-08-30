#include "bgfx_alloc.h"
#include <bx/allocator.h>
#include <atomic>
#include <malloc.h>

#ifndef BX_CONFIG_ALLOCATOR_NATURAL_ALIGNMENT
#	define BX_CONFIG_ALLOCATOR_NATURAL_ALIGNMENT 8
#endif

static bx::DefaultAllocator bx_alloc;
static std::atomic<int64_t> allocator_memory = 0;

#if BX_PLATFORM_WINDOWS
#define bx_malloc_size _msize
#elif BX_PLATFORM_LINUX
#define bx_malloc_size malloc_usable_size
#elif BX_PLATFORM_OSX
#define bx_malloc_size malloc_size
#elif BX_PLATFORM_IOS
#define bx_malloc_size malloc_size
#else
#	error "Unknown PLATFORM!"
#endif

#if BX_COMPILER_MSVC
#endif

static void* originalPtr(void* _ptr, size_t _align) {
#if BX_COMPILER_MSVC
    return _ptr;
#else
    if (BX_CONFIG_ALLOCATOR_NATURAL_ALIGNMENT >= _align) {
        return _ptr;
    }
    uint8_t* aligned = (uint8_t*)_ptr;
    uint32_t* header = (uint32_t*)aligned - 1;
    uint8_t* ptr = aligned - *header;
    return ptr;
#endif
}

static void* allocator_realloc(bgfx_allocator_interface_t* /*_this*/, void* _ptr, size_t _size, size_t _align, const char* _file, uint32_t _line) {
    if (_ptr) {
        allocator_memory -= bx_malloc_size(originalPtr(_ptr, _align));
    }
    void* newptr = bx_alloc.realloc(_ptr, _size, _align, _file, _line);
    if (newptr) {
        allocator_memory += bx_malloc_size(originalPtr(newptr, _align));
    }
    return newptr;
}

static bgfx_allocator_vtbl_t      allocator_vtbl = {.realloc=allocator_realloc};
static bgfx_allocator_interface_t allocator_impl = {.vtbl=&allocator_vtbl};

int luabgfx_getalloc(bgfx_allocator_interface_t** pinterface) {
    *pinterface = &allocator_impl;
    return 1;
}

int luabgfx_info(int64_t* psize) {
    *psize = allocator_memory;
    return 1;
}
