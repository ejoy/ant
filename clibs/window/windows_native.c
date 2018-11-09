#define LUA_LIB

#include <lua.h>
#include <lua.h>
#include <lauxlib.h>
#include <windows.h>
#include "window.h"

// project path in my documents
#define CLASSNAME L"ANTCLIENT"
#define WINDOWSTYLE (WS_OVERLAPPEDWINDOW & ~WS_THICKFRAME & ~WS_MAXIMIZEBOX)

static void
get_xy(LPARAM lParam, int *x, int *y) {
	*x = (short)(lParam & 0xffff); 
	*y = (short)((lParam>>16) & 0xffff); 
}

static LRESULT CALLBACK
WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	struct ant_window_callback *cb = NULL;
	struct ant_window_message msg;
	switch (message) {
	case WM_CREATE: {
		LPCREATESTRUCTA cs = (LPCREATESTRUCTA)lParam;
		cb = (struct ant_window_callback *)cs->lpCreateParams;
		SetWindowLongPtr(hWnd, GWLP_USERDATA, (LONG_PTR)cb);
		break;
	}
//	case WM_PAINT: {
//		if (GetUpdateRect(hWnd, NULL, FALSE)) {
//			// todo: paint
//			ValidateRect(hWnd, NULL);
//		}
//		return 0;
//	}
	case WM_DESTROY:
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		msg.type = ANT_WINDOW_EXIT;
		cb->message(cb->ud, &msg);
		PostQuitMessage(0);
		return 0;
	case WM_LBUTTONUP:
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		msg.type = ANT_WINDOW_TOUCH;
		msg.u.touch.what = 0;
		get_xy(lParam, &msg.u.touch.x, &msg.u.touch.y);
		cb->message(cb->ud, &msg);
		break;
	case WM_LBUTTONDOWN:
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		msg.type = ANT_WINDOW_TOUCH;
		msg.u.touch.what = 1;
		get_xy(lParam, &msg.u.touch.x, &msg.u.touch.y);
		cb->message(cb->ud, &msg);
		break;
	case WM_MOUSEMOVE:
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		msg.type = ANT_WINDOW_MOVE;
		get_xy(lParam, &msg.u.move.x, &msg.u.move.y);
		cb->message(cb->ud, &msg);
		break;
	}
	return DefWindowProcW(hWnd, message, wParam, lParam);
}

static void
register_class()
{
	WNDCLASSW wndclass;

	wndclass.style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
	wndclass.lpfnWndProc = WndProc;
	wndclass.cbClsExtra = 0;
	wndclass.cbWndExtra = 0;
	wndclass.hInstance = GetModuleHandleW(0);
	wndclass.hIcon = 0;
	wndclass.hCursor = 0;
	wndclass.hbrBackground = 0;
	wndclass.lpszMenuName = 0; 
	wndclass.lpszClassName = CLASSNAME;

	RegisterClassW(&wndclass);
}

static void
default_message_handle(void *ud, struct ant_window_message *msg) {
	// dummy handle
	(void)ud;
	printf("Unhandle message %d\n", msg->type);
}

/*
	integer width
	integer height
	string title

	return lud HWND
 */
static int
lcreatewindow(lua_State *L) {
	int width = (int)luaL_checkinteger(L, 1);
	int height = (int)luaL_checkinteger(L, 2);
	size_t sz;
	const char * title = luaL_checklstring(L, 3, &sz);
	wchar_t *wtitle = (wchar_t *)lua_newuserdata(L, (sz + 1) * sizeof(wchar_t));
	int wsz = MultiByteToWideChar(CP_UTF8, 0, title, (int)sz+1, wtitle, (int)sz+1);
	if (wsz == 0)
		return luaL_error(L, "%s can't convert to utf8", title);
	struct ant_window_callback *cb = lua_newuserdata(L, sizeof(*cb));
	cb->ud = NULL;
	cb->message = default_message_handle;

	RECT rect;

	rect.left=0;
	rect.right=width;
	rect.top=0;
	rect.bottom=height;

	AdjustWindowRect(&rect,WINDOWSTYLE,0);

	register_class();

	HWND wnd=CreateWindowExW(0,CLASSNAME,wtitle,
		WINDOWSTYLE, CW_USEDEFAULT,0,
		rect.right-rect.left,rect.bottom-rect.top,
		0,0,
		GetModuleHandleW(0),
		cb);
	if (wnd == NULL) {
		return luaL_error(L, "Create window failed");
	}
	lua_setfield(L, LUA_REGISTRYINDEX, ANT_WINDOW_CALLBACK);

	ShowWindow(wnd, SW_SHOWDEFAULT);
	UpdateWindow(wnd);
	
	lua_pushlightuserdata(L, wnd);
	return 1;
}

static int
lmainloop(lua_State *L) {
	if (lua_getfield(L, LUA_REGISTRYINDEX, ANT_WINDOW_CALLBACK) != LUA_TUSERDATA) {
		return luaL_error(L, "Create native window first");
	}
	struct ant_window_callback *cb = lua_touserdata(L, -1);
	lua_pop(L, 1);

	MSG msg;
	struct ant_window_message update_msg;
	update_msg.type = ANT_WINDOW_UPDATE;

	for (;;) {
		if (PeekMessage (&msg, NULL, 0, 0, PM_REMOVE)) {
			if (msg.message == WM_QUIT)
				break;
			TranslateMessage(&msg); 
			DispatchMessage(&msg); 
		} else {
			cb->message(cb->ud, &update_msg);
			Sleep(0);
		}
	}

	return 0;
}

LUAMOD_API int
luaopen_window_native(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "create", lcreatewindow },
		{ "mainloop", lmainloop },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
