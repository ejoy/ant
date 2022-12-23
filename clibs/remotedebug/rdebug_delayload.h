#pragma once

#if defined(_MSC_VER) || defined(__MINGW32__) || defined(__MINGW64__)

#include <Windows.h>
#include <intrin.h>

namespace remotedebug::delayload {
	HMODULE get_luadll();
	void set_luadll(HMODULE handle);
	void set_luaapi(void* fn);
	void caller_is_luadll(void* callerAddress);
}

#endif
