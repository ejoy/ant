#if defined(_MSC_VER)

#include "rdebug_delayload.h"
#include <lua.hpp>
#define DELAYIMP_INSECURE_WRITABLE_HOOKS
#include <DelayImp.h>

#if LUA_VERSION_NUM == 504
#define LUA_DLL_NAME "lua54.dll"
#elif LUA_VERSION_NUM == 503
#define LUA_DLL_NAME "lua53.dll"
#elif LUA_VERSION_NUM == 502
#define LUA_DLL_NAME "lua52.dll"
#else
#error "Unknown Lua Version: " #LUA_VERSION_NUM
#endif

namespace remotedebug::delayload {
	typedef FARPROC (*FindLuaApi)(const char* name);
	static HMODULE    luadll = 0;
	static FindLuaApi luaapi = 0;

	void set_luadll(HMODULE handle) {
		if (luadll) return;
		luadll = handle;
	}

	void set_luaapi(void* fn) {
		if (luaapi) return;
		luaapi = (FindLuaApi)fn;
	}

	void caller_is_luadll(void* callerAddress) {
		if (luadll) return;
		HMODULE caller = NULL;
		if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS, (LPCWSTR)callerAddress, &caller) && caller) {
			if (GetProcAddress(caller, "lua_newstate")) {
				set_luadll(caller);
			}
		}
	}

	static FARPROC WINAPI hook(unsigned dliNotify, PDelayLoadInfo pdli) {
		switch (dliNotify) {
		case dliNotePreLoadLibrary:
			if (strcmp(LUA_DLL_NAME, pdli->szDll) == 0) {
				if (luadll) {
					return (FARPROC)luadll;
				}
			}
			return NULL;
		case dliNotePreGetProcAddress: {
			if (luaapi) {
				FARPROC fn = luaapi(pdli->dlp.szProcName);
				if (fn) {
					return fn;
				}
			}
			FARPROC ret = ::GetProcAddress(pdli->hmodCur, pdli->dlp.szProcName);
			if (ret) {
				return ret;
			}
			char str[256];
			sprintf(str, "Can't find lua c function: `%s`.", pdli->dlp.szProcName);
			MessageBoxA(0, str, "Fatal Error.", 0);
			return NULL;
		}
		case dliStartProcessing:
		case dliFailLoadLib:
		case dliFailGetProc:
		case dliNoteEndProcessing:
		default:
			return NULL;
		}
		return NULL;
	}
}

PfnDliHook __pfnDliNotifyHook2 = remotedebug::delayload::hook;

#endif
