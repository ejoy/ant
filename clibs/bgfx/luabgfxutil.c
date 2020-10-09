#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include <math.h>

#include "bgfx_interface.h"

static inline float
fclamp(float _a, float _min, float _max) {
	return fmin(fmax(_a, _min), _max);
}

static inline float
fsaturate(float _a) {
	return fclamp(_a, 0.0f, 1.0f);
}

static inline float
fround(float _f) {
	return floor(_f + 0.5f);
}

static inline uint32_t
toUnorm(float value, float scale) {
	return (uint32_t)(fround(fsaturate(value) * scale));
}

static inline void
packRgba8(void* dst_, const float* src) {
	uint8_t* dst = (uint8_t*)dst_;
	dst[0] = (uint8_t)(toUnorm(src[0], 255.0f) );
	dst[1] = (uint8_t)(toUnorm(src[1], 255.0f) );
	dst[2] = (uint8_t)(toUnorm(src[2], 255.0f) );
	dst[3] = (uint8_t)(toUnorm(src[3], 255.0f) );
}

static int
lencodeNormalRgba8(lua_State *L) {
	float x = luaL_checknumber(L, 1);
	float y = luaL_optnumber(L, 2, 0);
	float z = luaL_optnumber(L, 3, 0);
	float w = luaL_optnumber(L, 4, 0);

	const float src[] =	{
		x * 0.5f + 0.5f,
		y * 0.5f + 0.5f,
		z * 0.5f + 0.5f,
		w * 0.5f + 0.5f,
	};
	uint32_t dst;
	packRgba8(&dst, src);
	lua_pushinteger(L, dst);
	return 1;
}

static void
update_char_texture(uint16_t texid, 
	uint16_t _layer, uint8_t _mip, 
	uint16_t _x, uint16_t _y, uint16_t _width, uint16_t _height, uint16_t _pitch,
	const uint8_t *mem, void (*release_fn)(void*, void*)){

	bgfx_texture_handle_t th = {texid};
	const bgfx_memory_t *m = BGFX(make_ref_release)(mem, _width * _height, release_fn, NULL);
	BGFX(update_texture_2d)(th, _layer, _mip, _x, _y, _width, _height, m, _pitch);
}

LUAMOD_API int
luaopen_bgfx_util(lua_State *L) {
	luaL_checkversion(L);
	init_interface(L);
	luaL_Reg l[] = {
		{ "update_char_texture", NULL},
		{ "encodeNormalRgba8", lencodeNormalRgba8 },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	lua_pushlightuserdata(L, update_char_texture);
	lua_setfield(L, -2, "update_char_texture");
	return 1;
}
