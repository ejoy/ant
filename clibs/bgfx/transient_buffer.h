#ifndef transient_buffer_h
#define transient_buffer_h

#include <bgfx/c99/bgfx.h>

struct transient_buffer {
	bgfx_transient_vertex_buffer_t tvb;
	bgfx_transient_index_buffer_t tib;
	int cap_v;
	int cap_i;
	char index32;
	char format[1];
};

typedef int (*lua_TBFunction)(lua_State *L, struct transient_buffer *tb);

#endif