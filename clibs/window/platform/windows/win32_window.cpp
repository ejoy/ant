#include <Windows.h>
#include <stdint.h>
#include <stddef.h>
#include "../../window.h"

#define CLASSNAME L"ANTCLIENT"

static void get_xy(LPARAM lParam, int *x, int *y) {
	*x = (short)(lParam & 0xffff); 
	*y = (short)((lParam>>16) & 0xffff); 
}

static void get_screen_xy(HWND hwnd, LPARAM lParam, int *x, int *y) {
	get_xy(lParam, x, y);
	POINT pt = { *x, *y };
	ScreenToClient(hwnd, &pt);
	*x = pt.x;
	*y = pt.y;
}

static LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
	struct ant_window_callback *cb = NULL;
	switch (message) {
	case WM_CREATE: {
		LPCREATESTRUCTA cs = (LPCREATESTRUCTA)lParam;
		cb = (struct ant_window_callback *)cs->lpCreateParams;
		SetWindowLongPtr(hWnd, GWLP_USERDATA, (LONG_PTR)cb);
		RECT r;
		GetClientRect(hWnd, &r);
		window_message_init(cb, hWnd, 0, r.right-r.left, r.bottom-r.top);
		break;
	}
	case WM_DESTROY:
		cb = (struct ant_window_callback*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		PostQuitMessage(0);
		window_message_exit(cb);
		return 0;
	case WM_MOUSEWHEEL: {
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		struct ant::window::msg_mousewheel msg;
		msg.delta = 1.0f * GET_WHEEL_DELTA_WPARAM(wParam) / WHEEL_DELTA;
		get_screen_xy(hWnd, lParam, &msg.x, &msg.y);
		ant::window::input_message(cb, msg);
		break;
	}
	case WM_MOUSEMOVE:
		if (wParam & MK_LBUTTON) {
			cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
			struct ant::window::msg_mouse msg;
			msg.type = ant::window::MOUSE_LEFT;
			msg.state = ant::window::MOUSE_MOVE;
			get_xy(lParam, &msg.x, &msg.y);
			ant::window::input_message(cb, msg);
		}
		if (wParam & MK_MBUTTON) {
			cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
			struct ant::window::msg_mouse msg;
			msg.type = ant::window::MOUSE_MIDDLE;
			msg.state = ant::window::MOUSE_MOVE;
			get_xy(lParam, &msg.x, &msg.y);
			ant::window::input_message(cb, msg);
		}
		if (wParam & MK_RBUTTON) {
			cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
			struct ant::window::msg_mouse msg;
			msg.type = ant::window::MOUSE_RIGHT;
			msg.state = ant::window::MOUSE_MOVE;
			get_xy(lParam, &msg.x, &msg.y);
			ant::window::input_message(cb, msg);
		}
		break;
	case WM_LBUTTONDOWN:
	case WM_LBUTTONUP: {
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		struct ant::window::msg_mouse msg;
		msg.type = ant::window::MOUSE_LEFT;
		msg.state = (message == WM_LBUTTONDOWN) ? ant::window::MOUSE_DOWN : ant::window::MOUSE_UP;
		get_xy(lParam, &msg.x, &msg.y);
		ant::window::input_message(cb, msg);
		break;
	}
	case WM_MBUTTONDOWN:
	case WM_MBUTTONUP: {
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		struct ant::window::msg_mouse msg;
		msg.type = ant::window::MOUSE_MIDDLE;
		msg.state = (message == WM_MBUTTONDOWN) ? ant::window::MOUSE_DOWN : ant::window::MOUSE_UP;
		get_xy(lParam, &msg.x, &msg.y);
		ant::window::input_message(cb, msg);
		break;
	}
	case WM_RBUTTONDOWN:
	case WM_RBUTTONUP: {
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		struct ant::window::msg_mouse msg;
		msg.type = ant::window::MOUSE_RIGHT;
		msg.state = (message == WM_RBUTTONDOWN) ? ant::window::MOUSE_DOWN : ant::window::MOUSE_UP;
		get_xy(lParam, &msg.x, &msg.y);
		ant::window::input_message(cb, msg);
		break;
	}
	case WM_KEYDOWN:
	case WM_KEYUP: {
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		uint8_t press;
		if (message == WM_KEYUP) {
			press = 0;
		}
		else {
			press = (lParam & (1 << 30))? 2: 1;
		}
		struct ant::window::msg_keyboard msg;
		msg.key = (int)wParam;
		msg.state = ant::window::get_keystate(
			GetKeyState(VK_CONTROL) < 0,
			GetKeyState(VK_SHIFT) < 0,
			GetKeyState(VK_MENU) < 0,
			(GetKeyState(VK_LWIN) < 0) || (GetKeyState(VK_RWIN) < 0),
			lParam & (0x1 << 24)
		);
		msg.press = press;
		ant::window::input_message(cb, msg);
		break;
	}
	case WM_SIZE: {
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		int x = LOWORD(lParam);
		int y = HIWORD(lParam);
		uint8_t type;
		switch (wParam) {
		case SIZE_MINIMIZED:
			type = 1;
			break;
		case SIZE_MAXIMIZED:
			type = 2;
			break;
		default:
			type = 0;
			break;
		}
		window_message_size(cb, x, y, type);
		break;
	}
	default:
		break;
	}
	return DefWindowProcW(hWnd, message, wParam, lParam);
}

int window_init(struct ant_window_callback* cb) {
	int w = 1334;
	int h = 750;
	RECT rect;
	rect.left = 0;
	rect.right = w;
	rect.top = 0;
	rect.bottom = h;
	AdjustWindowRect(&rect, WS_OVERLAPPEDWINDOW, 0);

	WNDCLASSEXW wndclass;
	memset(&wndclass, 0, sizeof(wndclass));
	wndclass.cbSize = sizeof(wndclass);
	wndclass.style = CS_HREDRAW | CS_VREDRAW;// | CS_OWNDC;
	wndclass.lpfnWndProc = WndProc;
	wndclass.hInstance = GetModuleHandleW(0);
	wndclass.hIcon = LoadIconW(NULL, (LPCWSTR)IDI_APPLICATION);
	wndclass.hCursor = LoadCursorW(NULL, (LPCWSTR)IDC_ARROW);
	wndclass.lpszClassName = CLASSNAME;
	RegisterClassExW(&wndclass);

	HWND wnd = CreateWindowExW(0, CLASSNAME, NULL,
		WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, 0,
		rect.right-rect.left,
		rect.bottom-rect.top,
		0, 0,
		GetModuleHandleW(0),
		cb);
	if (wnd == NULL) {
		return 1;
	}
	ShowWindow(wnd, SW_SHOWDEFAULT);
	UpdateWindow(wnd);
	return 0;
}

void window_close() {
	UnregisterClassW(CLASSNAME, GetModuleHandleW(0));
}

bool window_peekmessage() {
	MSG msg;
	for (;;) {
		if (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
			if (msg.message == WM_QUIT)
				return false;
			if ((msg.message == WM_KEYDOWN || msg.message == WM_KEYUP) && msg.wParam == VK_PROCESSKEY) {
				msg.wParam = ImmGetVirtualKey(msg.hwnd);
			}
			TranslateMessage(&msg);
			DispatchMessageW(&msg);
		}
		else {
			return true;
		}
	}
}
