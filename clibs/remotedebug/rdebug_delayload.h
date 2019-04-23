#pragma once

#if defined(_MSC_VER)

#include <Windows.h>
#include <intrin.h>

namespace remotedebug::delayload {
	typedef FARPROC (__stdcall* GetLuaApi)(HMODULE m, const char* name);
	void set_luadll(HMODULE handle, GetLuaApi fn);
    void caller_is_luadll(void* callerAddress);
}

#endif
