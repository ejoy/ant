#pragma once

#include <bgfx/c99/bgfx.h>

#if defined(__cplusplus)
extern "C" {
#endif

int luabgfx_getalloc(bgfx_allocator_interface_t** interface_t);
int luabgfx_info(int64_t* psize);

#if defined(__cplusplus)
}
#endif
