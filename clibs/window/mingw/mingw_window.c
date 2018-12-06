#include <Windows.h>
#include <stdint.h>
#include "../window_native.h"

// project path in my documents
#define CLASSNAME L"ANTCLIENT"
#define WINDOWSTYLE (WS_OVERLAPPEDWINDOW & ~WS_THICKFRAME & ~WS_MAXIMIZEBOX)

static int  g_w = 0;
static int  g_h = 0;
static HWND g_wnd = 0;

static void
get_xy(LPARAM lParam, int *x, int *y) {
	*x = (short)(lParam & 0xffff); 
	*y = (short)((lParam>>16) & 0xffff); 
}

static void
get_screen_xy(HWND hwnd, LPARAM lParam, int *x, int *y) {
	get_xy(lParam, x, y);
	POINT pt = { *x, *y };
	ScreenToClient(hwnd, &pt);
	*x = pt.x;
	*y = pt.y;
}

static uint8_t get_keystate(LPARAM lParam) {
	return 0
		| GetKeyState(VK_SHIFT)                          ? (uint8_t)(1 << KB_SHIFT)    : 0
		| GetKeyState(VK_MENU)                           ? (uint8_t)(1 << KB_ALT)      : 0
		| GetKeyState(VK_CONTROL)                        ? (uint8_t)(1 << KB_CTRL)     : 0
		| (GetKeyState(VK_LWIN) || GetKeyState(VK_RWIN)) ? (uint8_t)(1 << KB_SYS)      : 0
		| (lParam & (0x1 << 24))                         ? (uint8_t)(1 << KB_CAPSLOCK) : 0
		;
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
	case WM_DESTROY:
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		msg.type = ANT_WINDOW_EXIT;
		cb->message(cb->ud, &msg);
		PostQuitMessage(0);
		return 0;
	case WM_MOUSEMOVE:
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		msg.type = ANT_WINDOW_MOUSE_MOVE;
		msg.u.mouse_move.state = 0
			| ((wParam & MK_LBUTTON) ? 1 : 0)
			| ((wParam & MK_RBUTTON) ? 2 : 0)
			| ((wParam & MK_MBUTTON) ? 4 : 0)
			;
		get_xy(lParam, &msg.u.mouse_move.x, &msg.u.mouse_move.y);
		cb->message(cb->ud, &msg);
		break;
	case WM_MOUSEWHEEL:
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		msg.type = ANT_WINDOW_MOUSE_WHEEL;
		get_screen_xy(hWnd, lParam, &msg.u.mouse_wheel.x, &msg.u.mouse_wheel.y);
		msg.u.mouse_wheel.delta = 1.0f * GET_WHEEL_DELTA_WPARAM(wParam) / WHEEL_DELTA;
		cb->message(cb->ud, &msg);
		break;
	case WM_LBUTTONDOWN:
	case WM_LBUTTONUP:
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		msg.type = ANT_WINDOW_MOUSE_CLICK;
		msg.u.mouse_click.type = 0;
		msg.u.mouse_click.press = (message == WM_LBUTTONDOWN) ? 1 : 0;
		get_xy(lParam, &msg.u.mouse_click.x, &msg.u.mouse_click.y);
		cb->message(cb->ud, &msg);
		break;
	case WM_RBUTTONDOWN:
	case WM_RBUTTONUP:
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		msg.type = ANT_WINDOW_MOUSE_CLICK;
		msg.u.mouse_click.type = 1;
		msg.u.mouse_click.press = (message == WM_RBUTTONDOWN) ? 1 : 0;
		get_xy(lParam, &msg.u.mouse_click.x, &msg.u.mouse_click.y);
		cb->message(cb->ud, &msg);
		break;
	case WM_MBUTTONDOWN:
	case WM_MBUTTONUP:
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		msg.type = ANT_WINDOW_MOUSE_CLICK;
		msg.u.mouse_click.type = 2;
		msg.u.mouse_click.press = (message == WM_MBUTTONDOWN) ? 1 : 0;
		get_xy(lParam, &msg.u.mouse_click.x, &msg.u.mouse_click.y);
		cb->message(cb->ud, &msg);
		break;
	case WM_KEYDOWN:
	case WM_KEYUP:
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		msg.type = ANT_WINDOW_KEYBOARD;
		msg.u.keyboard.state = get_keystate(lParam);
		msg.u.keyboard.press = (message == WM_KEYDOWN) ? 1 : 0;
		msg.u.keyboard.key = (int)wParam;
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

int window_create(struct ant_window_callback* cb, int w, int h, const char* title, size_t sz) {
	wchar_t* wtitle = (wchar_t *)malloc((sz + 1) * sizeof(wchar_t));
	if (wtitle == 0) {
		return 1;
	}
	int wsz = MultiByteToWideChar(CP_UTF8, 0, title, (int)sz+1, wtitle, (int)sz+1);
	if (wsz == 0) {
		free(wtitle);
		return 2;
	}

	RECT rect;
	rect.left=0;
	rect.right=w;
	rect.top=0;
	rect.bottom=h;
	AdjustWindowRect(&rect,WINDOWSTYLE,0);
	register_class();
	HWND wnd=CreateWindowExW(0,CLASSNAME,wtitle,
		WINDOWSTYLE, CW_USEDEFAULT,0,
		rect.right-rect.left,rect.bottom-rect.top,
		0,0,
		GetModuleHandleW(0),
		cb);
	free(wtitle);
	if (wnd == NULL) {
		return 3;
	}
	ShowWindow(wnd, SW_SHOWDEFAULT);
	UpdateWindow(wnd);
	g_w = w;
	g_h = h;
	g_wnd = wnd;
	return 0;
}

void window_mainloop(struct ant_window_callback* cb) {
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
	UnregisterClassW(CLASSNAME, GetModuleHandleW(0));
}

int window_gethandle(struct ant_window_callback* cb, void** handle) {
	if (!g_wnd) {
		return 1;
	}
	*handle = (void*)g_wnd;
	return 0;
}

int window_getsize(struct ant_window_callback* cb, struct windowSize* size) {
	if (!g_wnd) {
		return 1;
	}
	size->w = g_w;
	size->h = g_h;
	return 0;
}
