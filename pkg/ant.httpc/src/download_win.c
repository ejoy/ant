#define LUA_LIB

#include <windows.h>
#include <urlmon.h>
#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>

struct download_cancel {
	int cancel;
};

struct download_callback {
	const IBindStatusCallbackVtbl * vtbl;
	lua_State *L;
	uint64_t id;
	struct download_cancel *c;
};

static HRESULT STDMETHODCALLTYPE
cbQueryInterface(IBindStatusCallback* This, REFIID riid, void **ppvObject) {
	return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE
cbAddRef(IBindStatusCallback* This) {
	return 1;
}

static ULONG STDMETHODCALLTYPE
cbRelease(IBindStatusCallback* This) {
	return 1;
}

static inline HRESULT
default_result(IBindStatusCallback* This, HRESULT d) {
	struct download_callback *cb = (struct download_callback *)This;
	if (cb->c) {
		if (cb->c->cancel) {
			return E_ABORT;
		}
	}
	return d;
}

static HRESULT STDMETHODCALLTYPE
cbOnStartBinding(IBindStatusCallback* This, DWORD dwReserved, IBinding *pib) {
	return default_result(This, E_NOTIMPL);
}

static HRESULT STDMETHODCALLTYPE
cbGetPriority(IBindStatusCallback* This, LONG *pnPriority) {
	return default_result(This, E_NOTIMPL);
}

static HRESULT STDMETHODCALLTYPE
cbOnLowResource(IBindStatusCallback* This, DWORD reserved) {
	return default_result(This, S_OK);
}

static HRESULT STDMETHODCALLTYPE
cbOnStopBinding(IBindStatusCallback* This, HRESULT hresult, LPCWSTR szError) {
	return default_result(This, E_NOTIMPL);
}

static HRESULT STDMETHODCALLTYPE
cbGetBindInfo(IBindStatusCallback* This, DWORD *grfBINDF, BINDINFO *pbindinfo) {
	return default_result(This, E_NOTIMPL);
}

static HRESULT STDMETHODCALLTYPE
cbOnDataAvailable(IBindStatusCallback* This, DWORD grfBSCF, DWORD dwSize, FORMATETC *pformatetc, STGMEDIUM *pstgmed) {
	return default_result(This, E_NOTIMPL);
}

static HRESULT STDMETHODCALLTYPE
cbOnObjectAvailable(IBindStatusCallback* This, REFIID riid, IUnknown *punk) {
	return default_result(This, E_NOTIMPL);
}

static HRESULT STDMETHODCALLTYPE
cbOnProgress(IBindStatusCallback* This, ULONG ulProgress, ULONG ulProgressMax, ULONG ulStatusCode, LPCWSTR szStatusText) {
	struct download_callback *cb = (struct download_callback *)This;
	lua_State *L = cb->L;
	lua_pushvalue(L, 3);
	lua_pushinteger(L, cb->id);
	lua_pushinteger(L, ulProgress);
	lua_pushinteger(L, ulProgressMax);
	lua_pushinteger(L, ulStatusCode);
	if (lua_pcall(L, 4, 0, 0) != LUA_OK) {
		lua_pop(L, 1);
	}
	return default_result(This, S_OK);
}

const struct IBindStatusCallbackVtbl callback_vtbl = {
	cbQueryInterface,
	cbAddRef,
	cbRelease,
	cbOnStartBinding,
	cbGetPriority,
	cbOnLowResource,
	cbOnProgress,
	cbOnStopBinding,
	cbGetBindInfo,
	cbOnDataAvailable,
	cbOnObjectAvailable,
};

#define MAXFILENAME 4096

static int
ldownload(lua_State *L) {
	const char * url = luaL_checkstring(L, 1);
	const char * filename = luaL_checkstring(L, 2);
	WCHAR url_w[MAXFILENAME];
	if (MultiByteToWideChar(CP_UTF8, 0, url, -1, url_w, MAXFILENAME) == 0) {
		return luaL_error(L, "Can't convert %s to utf16", url);
	}
	WCHAR filename_w[MAXFILENAME];
	if (MultiByteToWideChar(CP_UTF8, 0, filename, -1, filename_w, MAXFILENAME) == 0) {
		return luaL_error(L, "Can't convert %s to utf16", filename);
	}
	struct download_callback download_cb = {
		&callback_vtbl,
		L,
		(uint64_t)luaL_optinteger(L, 4, 0),
		NULL,
	};
	IBindStatusCallback *cb = NULL;
	if (lua_type(L, 3) == LUA_TFUNCTION) {
		cb = (IBindStatusCallback *)&download_cb;
		download_cb.c = lua_touserdata(L, 5);
	};
	HRESULT hr = URLDownloadToFileW(NULL, url_w, filename_w, 0, cb);
	if (hr != S_OK) {
		return luaL_error(L, "Download %s failed", url);
	}
	return 0;
}

static int
lcancel_object(lua_State *L) {
	struct download_cancel *c = lua_newuserdatauv(L, sizeof(*c), 0);
	c->cancel = 0;
	lua_pushlightuserdata(L, c);
	return 2;
}

static int
lcancel(lua_State *L) {
	struct download_cancel *c = (struct download_cancel *)lua_touserdata(L, 1);
	c->cancel = 1;
	return 0;
}

LUAMOD_API int
luaopen_httpc(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "cancel_object", lcancel_object },
		{ "cancel", lcancel },
		{ "download", ldownload },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
