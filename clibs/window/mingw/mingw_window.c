#include <Windows.h>
#include <stdint.h>
#include "../window.h"
#include "mingw_window.h"


// project path in my documents
#define CLASSNAME L"ANTCLIENT"
#define WINDOWSTYLE (WS_OVERLAPPEDWINDOW)


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
		| ((GetKeyState(VK_CONTROL) < 0)
			? (uint8_t)(1 << KB_CTRL) : 0)
		| ((GetKeyState(VK_MENU) < 0)
			? (uint8_t)(1 << KB_ALT) : 0)
		| ((GetKeyState(VK_SHIFT) < 0)
			? (uint8_t)(1 << KB_SHIFT) : 0)
		| (((GetKeyState(VK_LWIN) < 0) || (GetKeyState(VK_RWIN) < 0)) 
			? (uint8_t)(1 << KB_SYS) : 0)
		| ((lParam & (0x1 << 24))
			? (uint8_t)(1 << KB_CAPSLOCK) : 0)
		;
}

int g_surrogate = 0;

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

		msg.type = ANT_WINDOW_INIT;
		msg.u.init.window = hWnd;
		msg.u.init.context = 0;
		msg.u.init.w = cs->cx;
		msg.u.init.h = cs->cy;
		cb->message(cb->ud, &msg);

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
		msg.type = ANT_WINDOW_MOUSE;
		msg.u.mouse.state = 2;
		get_xy(lParam, &msg.u.mouse.x, &msg.u.mouse.y);
		if ((wParam & (MK_LBUTTON | MK_RBUTTON | MK_RBUTTON)) == 0) {
			msg.u.mouse.type = 0;
			cb->message(cb->ud, &msg);
		}
		else {

			if (wParam & MK_LBUTTON) {
				msg.u.mouse.type = 1;
				cb->message(cb->ud, &msg);
			}
			if (wParam & MK_RBUTTON) {
				msg.u.mouse.type = 2;
				cb->message(cb->ud, &msg);
			}
			if (wParam & MK_MBUTTON) {
				msg.u.mouse.type = 3;
				cb->message(cb->ud, &msg);
			}
		}
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
		msg.type = ANT_WINDOW_MOUSE;
		msg.u.mouse.type = 1;
		msg.u.mouse.state = (message == WM_LBUTTONDOWN) ? 1 : 3;
		get_xy(lParam, &msg.u.mouse.x, &msg.u.mouse.y);
		cb->message(cb->ud, &msg);
		break;
	case WM_RBUTTONDOWN:
	case WM_RBUTTONUP:
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		msg.type = ANT_WINDOW_MOUSE;
		msg.u.mouse.type = 2;
		msg.u.mouse.state = (message == WM_RBUTTONDOWN) ? 1 : 3;
		get_xy(lParam, &msg.u.mouse.x, &msg.u.mouse.y);
		cb->message(cb->ud, &msg);
		break;
	case WM_MBUTTONDOWN:
	case WM_MBUTTONUP:
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		msg.type = ANT_WINDOW_MOUSE;
		msg.u.mouse.type = 3;
		msg.u.mouse.state = (message == WM_MBUTTONDOWN) ? 1 : 3;
		get_xy(lParam, &msg.u.mouse.x, &msg.u.mouse.y);
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
	case WM_SIZE:
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		msg.type = ANT_WINDOW_SIZE;
		msg.u.size.x = LOWORD(lParam);
		msg.u.size.y = HIWORD(lParam);
		switch (wParam) {
		case SIZE_MINIMIZED:
			msg.u.size.type = 1;
			break;
		case SIZE_MAXIMIZED:
			msg.u.size.type = 2;
			break;
		default:
			msg.u.size.type = 0;
			break;
		}
		cb->message(cb->ud, &msg);
		break;
	case WM_CHAR: {
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		int code = (int)wParam;
		if (code >= 0xD800 && code <= 0xDBFF) {
			g_surrogate = code;
		} else {
			if (code >= 0xDC00 && code <= 0xDFFF) {
				code = ((g_surrogate - 0xD800) << 10) + (code - 0xDC00) + 0x10000;
				g_surrogate = 0;
			}
			msg.type = ANT_WINDOW_CHAR;
			msg.u.unichar.code = code;
			cb->message(cb->ud, &msg);
		}
		break;
	}
	case WM_USER_WINDOW_SETCURSOR:
	{
		LPTSTR cursor = (LPTSTR)lParam;
		HCURSOR hcursor = LoadCursor(NULL, cursor);
		SetCursor(hcursor);
		break;
	}

	}
	return DefWindowProcW(hWnd, message, wParam, lParam);
}

static void
register_class()
{
	WNDCLASSEXW wndclass;
	memset(&wndclass, 0, sizeof(wndclass));
	wndclass.cbSize = sizeof(wndclass);
	wndclass.style = CS_HREDRAW | CS_VREDRAW;// | CS_OWNDC;
	wndclass.lpfnWndProc = WndProc;
	wndclass.hInstance = GetModuleHandleW(0);
	wndclass.hIcon = LoadIcon(NULL, IDI_APPLICATION);
	//wndclass.hCursor = LoadCursor(NULL, IDC_ARROW);
	wndclass.lpszClassName = CLASSNAME;
	wndclass.hIconSm = LoadIcon(NULL, IDI_APPLICATION);

	RegisterClassExW(&wndclass);
}

int window_init(struct ant_window_callback* cb) {
    // do noting
    return 0;
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

	return 0;
}

void window_mainloop(struct ant_window_callback* cb) {
	MSG msg;
	while (GetMessage(&msg, NULL, 0, 0)) {
		TranslateMessage(&msg);
		DispatchMessage(&msg);
	}
	UnregisterClassW(CLASSNAME, GetModuleHandleW(0));
}

void window_ime(void* ime) {
    // do nothing
}
