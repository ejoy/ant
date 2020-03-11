#include <bx/platform.h>
#include <lua.hpp>
#include <stdint.h>

#if BX_PLATFORM_WINDOWS
#	include <windows.h>
static int64_t get_counter() {
	LARGE_INTEGER li;
	QueryPerformanceCounter(&li);
	return li.QuadPart;
}
static int64_t get_frequency() {
	LARGE_INTEGER li;
	QueryPerformanceFrequency(&li);
	return li.QuadPart;
}
#else
#	include <sys/time.h>
static int64_t get_counter() {
	struct timeval now;
	gettimeofday(&now, 0);
	return now.tv_sec * 1000000i64 + now.tv_usec;
}
static int64_t get_frequency() {
	return 1000000i64;
}
#endif

static int lcounter(lua_State *L){
	lua_pushinteger(L, get_counter());
	return 1;
}

static int lfrequency(lua_State* L) {
	lua_pushinteger(L, get_frequency());
	return 1;
}

extern "C"
#if BX_PLATFORM_WINDOWS
__declspec(dllexport)
#endif
int luaopen_platform_timer(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "counter",   lcounter },
		{ "frequency", lfrequency },
		{ NULL, NULL },
	};
	luaL_newlib(L,l);
	return 1;
}
