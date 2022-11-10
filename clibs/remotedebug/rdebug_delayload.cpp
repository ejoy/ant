#if defined(_MSC_VER)

#include "rdebug_delayload.h"
#include <lua.hpp>
#define DELAYIMP_INSECURE_WRITABLE_HOOKS
#include <DelayImp.h>

#if !defined(LUA_DLL_VERSION)
#error "Need LUA_DLL_VERSION"
#endif

#define LUA_STRINGIZE(_x) LUA_STRINGIZE_(_x)
#define LUA_STRINGIZE_(_x) #_x

#define LUA_DLL_NAME LUA_STRINGIZE(LUA_DLL_VERSION) ".dll"

namespace remotedebug::delayload {
	typedef FARPROC (*FindLuaApi)(const char* name);
	static HMODULE    luadll = 0;
	static FindLuaApi luaapi = 0;

	HMODULE get_luadll() {
		return luadll;
	}

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

	static int (*_lua_pcall)(lua_State *L, int nargs, int nresults, int errfunc);
	static int _lua_pcallk(lua_State *L, int nargs, int nresults, int errfunc, intptr_t ctx, intptr_t k) {
		return _lua_pcall(L,nargs,nresults,errfunc);
	}

	static int (*_luaL_loadbuffer)(lua_State *L, const char *buff, size_t size, const char *name);
	static int _luaL_loadbufferx(lua_State *L, const char *buff, size_t size, const char *name, const char *mode) {
		return _luaL_loadbuffer(L,buff,size,name);
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
			if (strcmp(pdli->dlp.szProcName, "lua_pcallk") == 0) {
				_lua_pcall = (int (__cdecl *)(lua_State *,int,int,int))::GetProcAddress(pdli->hmodCur, "lua_pcall");
				if (_lua_pcall) {
					return (FARPROC)_lua_pcallk;
				}
			}
			else if (strcmp(pdli->dlp.szProcName, "luaL_loadbufferx") == 0) {
				_luaL_loadbuffer = (int (__cdecl *)(lua_State *, const char *, size_t, const char *))::GetProcAddress(pdli->hmodCur, "luaL_loadbuffer");
				if (_luaL_loadbuffer) {
					return (FARPROC)_luaL_loadbufferx;
				}
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
