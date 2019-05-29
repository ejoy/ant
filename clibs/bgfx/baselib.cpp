#define LUA_LIB

#include <bx/platform.h>

extern "C" {

#include <lua.h>
#include <lauxlib.h>

}

#include <cstring>
#include <cstdint>

/// move from bx/timer.cpp
#if BX_CRT_NONE
#	include "crt0.h"
#elif BX_PLATFORM_ANDROID
#	include <time.h> // clock, clock_gettime
#elif BX_PLATFORM_EMSCRIPTEN
#	include <emscripten.h>
#elif BX_PLATFORM_WINDOWS || BX_PLATFORM_XBOXONE || BX_PLATFORM_WINRT
#	include <windows.h>
#else
#	include <sys/time.h> // gettimeofday
#endif // BX_PLATFORM_


int64_t getHPCounter() {
#if    BX_CRT_NONE
	int64_t i64 = crt0::getHPCounter();
#elif  BX_PLATFORM_WINDOWS \
|| BX_PLATFORM_XBOXONE \
|| BX_PLATFORM_WINRT
	LARGE_INTEGER li;
	QueryPerformanceCounter(&li);
	int64_t i64 = li.QuadPart;
#elif BX_PLATFORM_ANDROID
	struct timespec now;
	clock_gettime(CLOCK_MONOTONIC, &now);
	int64_t i64 = now.tv_sec*INT64_C(1000000000) + now.tv_nsec;
#elif BX_PLATFORM_EMSCRIPTEN
	int64_t i64 = int64_t(1000.0f * emscripten_get_now());
#elif !BX_PLATFORM_NONE
	struct timeval now;
	gettimeofday(&now, 0);
	int64_t i64 = now.tv_sec*INT64_C(1000000) + now.tv_usec;
#else
	BX_CHECK(false, "Not implemented!");
	int64_t i64 = UINT64_MAX;
#endif // BX_PLATFORM_
	return i64;
}

int64_t getHPFrequency() {
#if    BX_CRT_NONE
	return INT64_C(1000000000);
#elif  BX_PLATFORM_WINDOWS \
|| BX_PLATFORM_XBOXONE \
|| BX_PLATFORM_WINRT
	LARGE_INTEGER li;
	QueryPerformanceFrequency(&li);
	return li.QuadPart;
#elif BX_PLATFORM_ANDROID
	return INT64_C(1000000000);
#elif BX_PLATFORM_EMSCRIPTEN
	return INT64_C(1000000);
#else
	return INT64_C(1000000);
#endif // BX_PLATFORM_
}


static int
lgetHPCounter(lua_State *L){
	int64_t i64 = getHPCounter();
	lua_pushinteger(L, i64);
	return 1;
}

static int
lgetHPTime(lua_State *L){
	int64_t f = getHPFrequency();
	int64_t l = lua_tointeger(L, 1);

	const double t = (l / (double)f) * 1000.f;
	lua_pushnumber(L, t);
	return 1;
}

static int
lgetHPDeltaTime(lua_State *L) {
	int64_t c = getHPCounter();
	int64_t f = getHPFrequency();

	int64_t l = lua_tointeger(L, 1);

	double time = ((c - l) / (double)f) * 1000.f;	// 1000 for ms
	lua_pushnumber(L, time);
	return 1;
}

extern "C" {

LUAMOD_API int
luaopen_bgfx_baselib(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "HP_counter",		lgetHPCounter},
		{ "HP_deltatime",	lgetHPDeltaTime},
		{ "HP_time",		lgetHPTime},
		{ NULL, NULL },
	};

	luaL_newlib(L,l);
	int64_t i64 = getHPFrequency();
	lua_pushinteger(L, i64);
	lua_setfield(L, -2, "HP_frequency");
	return 1;
}

}
