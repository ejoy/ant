#ifndef lua_bgfx_h
#define lua_bgfx_h

#include <stdint.h>

#define BGFX_HANDLE_PROGRAM 1
#define BGFX_HANDLE_SHADER 2
#define BGFX_HANDLE_VERTEX_BUFFER 3
#define BGFX_HANDLE_INDEX_BUFFER 4
#define BGFX_HANDLE_DYNAMIC_VERTEX_BUFFER 5
#define BGFX_HANDLE_DYNAMIC_INDEX_BUFFER 6
#define BGFX_HANDLE_DYNAMIC_INDEX_BUFFER_32 7
#define BGFX_HANDLE_FRAME_BUFFER 8
#define BGFX_HANDLE_INDIRECT_BUFFER 9
#define BGFX_HANDLE_TEXTURE 10
#define BGFX_HANDLE_UNIFORM 11
#define BGFX_HANDLE_OCCLUSION_QUERY 12

#define BGFX_LUAHANDLE(type, handle) (BGFX_HANDLE_##type << 16 | handle.idx)
#define BGFX_LUAHANDLE_ID(type, idx) check_handle_type(L, BGFX_HANDLE_##type, (idx), #type)
#define BGFX_LUAHANDLE_WITHTYPE(idx, subtype) ( (idx) | (subtype) << 20 )
#define BGFX_LUAHANDLE_SUBTYPE(idx) ( (idx) >> 20 )

static inline int
check_handle_type(lua_State *L, int type, int id, const char * tname) {
	int idtype = (id >> 16) & 0x0f;
	if (idtype != type) {
		return luaL_error(L, "Invalid handle type %s (id = %d:%d)", tname, idtype, id&0xffff);
	}
	return id & 0xffff;
}

static int inline
hex2n(lua_State *L, char c) {
	if (c>='0' && c<='9')
		return c-'0';
	else if (c>='A' && c<='F')
		return c-'A' + 10;
	else if (c>='a' && c<='f')
		return c-'a' + 10;
	return luaL_error(L, "Invalid state %c", c);
}

static inline void
get_state(lua_State *L, int idx, uint64_t *pstate, uint32_t *prgba) {
	size_t sz;
	const uint8_t * data = (const uint8_t *)luaL_checklstring(L, idx, &sz);
	if (sz != 16 && sz != 24) {
		luaL_error(L, "Invalid state length %d", sz);
	}
	uint64_t state = 0;
	uint32_t rgba = 0;
	int i;
	for (i=0;i<15;i++) {
		state |= hex2n(L,data[i]);
		state <<= 4;
	}
	state |= hex2n(L,data[15]);
	if (sz == 24) {
		for (i=0;i<7;i++) {
			rgba |= hex2n(L,data[16+i]);
			rgba <<= 4;
		}
		rgba |= hex2n(L,data[23]);
	}
	*pstate = state;
	*prgba = rgba;
}

#endif
