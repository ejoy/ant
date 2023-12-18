#include <Windows.h>
#include <stdint.h>
#include <stddef.h>
#include <memory>
#include "../../window.h"

#define CLASSNAME L"ANTCLIENT"

struct DropManager : public IDropTarget {
	ULONG m_refcount = 0;
	ULONG AddRef() { return InterlockedIncrement(&m_refcount); }
	ULONG Release() { return InterlockedDecrement(&m_refcount); }
	HRESULT QueryInterface(REFIID iid, void** ppv) {
		if (IsEqualIID(iid, IID_IUnknown) || IsEqualIID(iid, IID_IDropTarget)) {
			*ppv = static_cast<IDropTarget*>(this);
			AddRef();
			return S_OK;
		}
		*ppv = NULL;
		return E_NOINTERFACE;
	}
	//---------------------------------------------
	//---------------------------------------------
	std::vector<std::string> m_files;
	struct ant_window_callback* m_cb = NULL;
	HWND m_window = NULL;

	HRESULT DragEnter(IDataObject* pDataObj, DWORD grfKeyState, POINTL pt, DWORD* pdwEffect) {
		FORMATETC fmte = { CF_HDROP, NULL, DVASPECT_CONTENT, -1, TYMED_HGLOBAL };
		STGMEDIUM stgm;
		if (SUCCEEDED(pDataObj->GetData(&fmte, &stgm))) {
			HDROP hdrop = reinterpret_cast<HDROP>(stgm.hGlobal);
			UINT n = DragQueryFileW(hdrop, 0xFFFFFFFF, NULL, 0);
			for (UINT i = 0; i < n; i++) {
				UINT wlen = ::DragQueryFileW(hdrop, i, NULL, 0);
				wlen++;
				std::unique_ptr<wchar_t[]> wstr(new wchar_t[wlen]);
				::DragQueryFileW(hdrop, i, wstr.get(), wlen);
				int len = ::WideCharToMultiByte(CP_UTF8, 0, wstr.get(), (int)wlen, NULL, 0, 0, 0);
				if (len > 0) {
					std::unique_ptr<char[]> str(new char[len]);
					::WideCharToMultiByte(CP_UTF8, 0, wstr.get(), (int)wlen, str.get(), len, 0, 0);
					m_files.push_back(std::string(str.get(), len - 1));
				}
				else {
					m_files.push_back("");
				}
			}
			ReleaseStgMedium(&stgm);
		}
		*pdwEffect &= DROPEFFECT_COPY;
		return S_OK;
	}
	HRESULT DragLeave() {
		m_files.clear();
		return S_OK;
	}
	HRESULT DragOver(DWORD grfKeyState, POINTL pt, DWORD* pdwEffect) {
		*pdwEffect &= DROPEFFECT_COPY;
		return S_OK;
	}
	HRESULT Drop(IDataObject* pDataObj, DWORD grfKeyState, POINTL pt, DWORD* pdwEffect) {
		window_message_dropfiles(m_cb, m_files);
		m_files.clear();
		*pdwEffect &= DROPEFFECT_COPY;
		return S_OK;
	}
	void Register(HWND window, struct ant_window_callback* cb) {
		m_window = window;
		m_cb = cb;
		RegisterDragDrop(m_window, this);
	}
	void Revoke() {
		RevokeDragDrop(m_window);
	}
};

static DropManager g_dropmanager;
static bool minimized = false;

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
			msg.what = ant::window::mouse_button::left;
			msg.state = ant::window::mouse_state::move;
			get_xy(lParam, &msg.x, &msg.y);
			ant::window::input_message(cb, msg);
		}
		if (wParam & MK_MBUTTON) {
			cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
			struct ant::window::msg_mouse msg;
			msg.what = ant::window::mouse_button::middle;
			msg.state = ant::window::mouse_state::move;
			get_xy(lParam, &msg.x, &msg.y);
			ant::window::input_message(cb, msg);
		}
		if (wParam & MK_RBUTTON) {
			cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
			struct ant::window::msg_mouse msg;
			msg.what = ant::window::mouse_button::right;
			msg.state = ant::window::mouse_state::move;
			get_xy(lParam, &msg.x, &msg.y);
			ant::window::input_message(cb, msg);
		}
		break;
	case WM_LBUTTONDOWN:
	case WM_LBUTTONUP: {
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		struct ant::window::msg_mouse msg;
		msg.what = ant::window::mouse_button::left;
		msg.state = (message == WM_LBUTTONDOWN) ? ant::window::mouse_state::down : ant::window::mouse_state::up;
		get_xy(lParam, &msg.x, &msg.y);
		ant::window::input_message(cb, msg);
		break;
	}
	case WM_MBUTTONDOWN:
	case WM_MBUTTONUP: {
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		struct ant::window::msg_mouse msg;
		msg.what = ant::window::mouse_button::middle;
		msg.state = (message == WM_MBUTTONDOWN) ? ant::window::mouse_state::down : ant::window::mouse_state::up;
		get_xy(lParam, &msg.x, &msg.y);
		ant::window::input_message(cb, msg);
		break;
	}
	case WM_RBUTTONDOWN:
	case WM_RBUTTONUP: {
		cb = (struct ant_window_callback *)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		struct ant::window::msg_mouse msg;
		msg.what = ant::window::mouse_button::right;
		msg.state = (message == WM_RBUTTONDOWN) ? ant::window::mouse_state::down : ant::window::mouse_state::up;
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
		if (wParam == SIZE_MINIMIZED) {
			minimized = true;
			ant::window::input_message(cb, {ant::window::suspend::will_suspend});
			ant::window::input_message(cb, {ant::window::suspend::did_suspend});
		}
		else if (minimized) {
			minimized = false;
			ant::window::input_message(cb, {ant::window::suspend::will_resume});
			ant::window::input_message(cb, {ant::window::suspend::did_resume});
		}
		else {
			window_message_size(cb, x, y);
		}
		break;
	}
	default:
		break;
	}
	return DefWindowProcW(hWnd, message, wParam, lParam);
}

#include <vector>

static BOOL CALLBACK EnumFunc(HMONITOR monitor, HDC, LPRECT, LPARAM dwData) {
	std::vector<MONITORINFO>& monitors = *reinterpret_cast<std::vector<MONITORINFO>*>(dwData);
	MONITORINFO info = {};
	info.cbSize = sizeof(MONITORINFO);
	if (!::GetMonitorInfoW(monitor, &info))
		return TRUE;
	if ((info.dwFlags & MONITORINFOF_PRIMARY) && !monitors.empty())
		monitors.insert(monitors.begin(), 1, info);
	else
		monitors.push_back(info);
	return TRUE;
}

static RECT createWindowRect() {
	std::vector<MONITORINFO> monitors;
	::EnumDisplayMonitors(nullptr, nullptr, EnumFunc, reinterpret_cast<LPARAM>(&monitors));
	auto& monitor = monitors[0];
	LONG work_w = monitor.rcWork.right - monitor.rcWork.left;
	LONG work_h = monitor.rcWork.bottom - monitor.rcWork.top;
	LONG window_w = (LONG)(work_w * 0.7f);
	LONG window_h = (LONG)(window_w / 16.f * 9.f);
	RECT rect;
	rect.left = monitor.rcWork.left + (work_w - window_w) / 2;
	rect.right = rect.left + window_w;
	rect.top = monitor.rcWork.top + (work_h - window_h) / 2;
	rect.bottom = rect.top + window_h;
	AdjustWindowRect(&rect, WS_OVERLAPPEDWINDOW, 0);
	return rect;
}

int window_init(struct ant_window_callback* cb) {
	if (FAILED(OleInitialize(NULL))) {
		return 1;
	}
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

	RECT rect = createWindowRect();
	HWND wnd = CreateWindowExW(0, CLASSNAME, NULL,
		WS_OVERLAPPEDWINDOW,
		rect.left, rect.top,
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
	g_dropmanager.Register(wnd, cb);
	return 0;
}

void window_close() {
	g_dropmanager.Revoke();
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
