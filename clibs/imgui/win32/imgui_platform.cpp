#include <ImGui.h>
#include <Windows.h>
#include <imm.h>
#include "../imgui_window.h"
#include "../imgui_platform.h"

#define MAX_DROP_PATH 255*3

enum {
	WM_USER_WINDOW_SETCURSOR = WM_USER,
};

struct PlatformViewport {
	HWND native_handle = NULL;
	bool owned = true;
	DWORD style = 0;
	DWORD exstyle = 0;
};

static HWND g_main_window = NULL;

static void set_cursor(ImGuiMouseCursor im_cursor) {
	LPTSTR cursor = NULL;
	switch (im_cursor) {
	default: [[fallthrough]] ;
	case ImGuiMouseCursor_Arrow:      cursor = IDC_ARROW;    break;
	case ImGuiMouseCursor_TextInput:  cursor = IDC_IBEAM;    break;
	case ImGuiMouseCursor_ResizeAll:  cursor = IDC_SIZEALL;  break;
	case ImGuiMouseCursor_ResizeEW:   cursor = IDC_SIZEWE;   break;
	case ImGuiMouseCursor_ResizeNS:   cursor = IDC_SIZENS;   break;
	case ImGuiMouseCursor_ResizeNESW: cursor = IDC_SIZENESW; break;
	case ImGuiMouseCursor_ResizeNWSE: cursor = IDC_SIZENWSE; break;
	case ImGuiMouseCursor_Hand:       cursor = IDC_HAND;     break;
	case ImGuiMouseCursor_None:       cursor = NULL;         break;
	}
	ImGuiViewport* main_viewport = ImGui::GetMainViewport();
	HWND  window = (HWND)(main_viewport->PlatformHandle);
	if (window != NULL)
		PostMessage(window, WM_USER_WINDOW_SETCURSOR, (WPARAM)NULL, (LPARAM)cursor);
	else if (cursor != NULL)
		::SetCursor(::LoadCursor(NULL, cursor));
	else
		::SetCursor(NULL);
}

static void platformSetImeInputPos(ImGuiViewport * viewport, ImVec2 pos) {
	COMPOSITIONFORM cf = { CFS_FORCE_POSITION,{ (LONG)(pos.x - viewport->Pos.x), (LONG)(pos.y - viewport->Pos.y) },{ 0, 0, 0, 0 } };
	if (HWND hwnd = (HWND)viewport->PlatformHandle)
		if (HIMC himc = ::ImmGetContext(hwnd)) {
			::ImmSetCompositionWindow(himc, &cf);
			::ImmReleaseContext(hwnd, himc);
		}
}

static void platformCreateWindow(ImGuiViewport* viewport) {
	PlatformViewport* ud = new PlatformViewport;
	viewport->PlatformUserData = ud;
	ud->style = (viewport->Flags & ImGuiViewportFlags_NoDecoration)
		? WS_POPUP
		: WS_OVERLAPPEDWINDOW;
	ud->exstyle = (viewport->Flags & ImGuiViewportFlags_NoTaskBarIcon)
		? WS_EX_TOOLWINDOW
		: WS_EX_APPWINDOW;
	if (viewport->Flags & ImGuiViewportFlags_TopMost) {
		ud->exstyle |= WS_EX_TOPMOST;
	}
	HWND parent_window = NULL;
	if (viewport->ParentViewportId != 0) {
		if (ImGuiViewport* parent_viewport = ImGui::FindViewportByID(viewport->ParentViewportId)) {
			parent_window = (HWND)parent_viewport->PlatformHandle;
		}
	}
	RECT rect = { (LONG)viewport->Pos.x, (LONG)viewport->Pos.y, (LONG)(viewport->Pos.x + viewport->Size.x), (LONG)(viewport->Pos.y + viewport->Size.y) };
	::AdjustWindowRectEx(&rect, ud->style, FALSE, ud->exstyle);
	ud->native_handle = ::CreateWindowExW(
		ud->exstyle, L"ImGui Platform", L"Untitled", ud->style,
		rect.left, rect.top, rect.right - rect.left, rect.bottom - rect.top,
		parent_window, NULL, ::GetModuleHandleW(NULL), window_get_callback((lua_State*)ImGui::GetIO().UserData)
	);
	viewport->PlatformRequestResize = false;
	viewport->PlatformHandle = viewport->PlatformHandleRaw = ud->native_handle;
}

static void platformDestroyWindow(ImGuiViewport* viewport) {
	if (PlatformViewport* ud = (PlatformViewport*)viewport->PlatformUserData) {
		if (::GetCapture() == ud->native_handle) {
			::ReleaseCapture();
			::SetCapture(g_main_window);
		}
		if (ud->native_handle && ud->owned)
			::DestroyWindow(ud->native_handle);
		ud->native_handle = NULL;
		delete ud;
	}
	viewport->PlatformUserData = nullptr;
	viewport->PlatformHandle = nullptr;
}

static void platformShowWindow(ImGuiViewport* viewport) {
	PlatformViewport* ud = (PlatformViewport*)viewport->PlatformUserData;
	if (viewport->Flags & ImGuiViewportFlags_NoFocusOnAppearing)
		::ShowWindow(ud->native_handle, SW_SHOWNA);
	else
		::ShowWindow(ud->native_handle, SW_SHOW);
}

static void platformUpdateWindow(ImGuiViewport* viewport) {
	PlatformViewport* ud = (PlatformViewport*)viewport->PlatformUserData;
	DWORD new_style = (viewport->Flags & ImGuiViewportFlags_NoDecoration)
		? WS_POPUP
		: WS_OVERLAPPEDWINDOW;
	DWORD new_ex_style = (viewport->Flags & ImGuiViewportFlags_NoTaskBarIcon)
		? WS_EX_TOOLWINDOW
		: WS_EX_APPWINDOW;
	if (viewport->Flags & ImGuiViewportFlags_TopMost) {
		new_ex_style |= WS_EX_TOPMOST;
	}
	if (ud->style != new_style || ud->exstyle != new_ex_style) {
		ud->style = new_style;
		ud->exstyle = new_ex_style;
		::SetWindowLong(ud->native_handle, GWL_STYLE, ud->style);
		::SetWindowLong(ud->native_handle, GWL_EXSTYLE, ud->exstyle);
		RECT rect = { (LONG)viewport->Pos.x, (LONG)viewport->Pos.y, (LONG)(viewport->Pos.x + viewport->Size.x), (LONG)(viewport->Pos.y + viewport->Size.y) };
		::AdjustWindowRectEx(&rect, ud->style, FALSE, ud->exstyle);
		::SetWindowPos(ud->native_handle, NULL, rect.left, rect.top, rect.right - rect.left, rect.bottom - rect.top, SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
		::ShowWindow(ud->native_handle, SW_SHOWNA);
		viewport->PlatformRequestMove = viewport->PlatformRequestResize = true;
	}
}

static ImVec2 platformGetWindowPos(ImGuiViewport* viewport) {
	PlatformViewport* ud = (PlatformViewport*)viewport->PlatformUserData;
	POINT pos = { 0, 0 };
	::ClientToScreen(ud->native_handle, &pos);
	return ImVec2((float)pos.x, (float)pos.y);
}

static void platformSetWindowPos(ImGuiViewport* viewport, ImVec2 pos) {
	PlatformViewport* ud = (PlatformViewport*)viewport->PlatformUserData;
	RECT rect = { (LONG)pos.x, (LONG)pos.y, (LONG)pos.x, (LONG)pos.y };
	::AdjustWindowRectEx(&rect, ud->style, FALSE, ud->exstyle);
	::SetWindowPos(ud->native_handle, NULL, rect.left, rect.top, 0, 0, SWP_NOZORDER | SWP_NOSIZE | SWP_NOACTIVATE);
}

static ImVec2 platformGetWindowSize(ImGuiViewport* viewport) {
	PlatformViewport* ud = (PlatformViewport*)viewport->PlatformUserData;
	RECT rect;
	::GetClientRect(ud->native_handle, &rect);
	return ImVec2(float(rect.right - rect.left), float(rect.bottom - rect.top));
}

static void platformSetWindowSize(ImGuiViewport* viewport, ImVec2 size) {
	PlatformViewport* ud = (PlatformViewport*)viewport->PlatformUserData;
	RECT rect = { 0, 0, (LONG)size.x, (LONG)size.y };
	::AdjustWindowRectEx(&rect, ud->style, FALSE, ud->exstyle);
	::SetWindowPos(ud->native_handle, NULL, 0, 0, rect.right - rect.left, rect.bottom - rect.top, SWP_NOZORDER | SWP_NOMOVE | SWP_NOACTIVATE);
}

static void platformSetWindowFocus(ImGuiViewport* viewport) {
	PlatformViewport* ud = (PlatformViewport*)viewport->PlatformUserData;
	::BringWindowToTop(ud->native_handle);
	::SetForegroundWindow(ud->native_handle);
	::SetFocus(ud->native_handle);
}

static bool platformGetWindowFocus(ImGuiViewport* viewport) {
	PlatformViewport* ud = (PlatformViewport*)viewport->PlatformUserData;
	return ::GetForegroundWindow() == ud->native_handle;
}

static bool platformGetWindowMinimized(ImGuiViewport* viewport) {
	PlatformViewport* ud = (PlatformViewport*)viewport->PlatformUserData;
	return ::IsIconic(ud->native_handle) != 0;
}

static void platformSetWindowTitle(ImGuiViewport* viewport, const char* title) {
	PlatformViewport* ud = (PlatformViewport*)viewport->PlatformUserData;
	int n = ::MultiByteToWideChar(CP_UTF8, 0, title, -1, NULL, 0);
	ImVector<wchar_t> title_w;
	title_w.resize(n);
	::MultiByteToWideChar(CP_UTF8, 0, title, -1, title_w.Data, n);
	::SetWindowTextW(ud->native_handle, title_w.Data);
}

static void platformSetWindowAlpha(ImGuiViewport* viewport, float alpha) {
	PlatformViewport* ud = (PlatformViewport*)viewport->PlatformUserData;
	assert(alpha >= 0.0f && alpha <= 1.0f);
	if (alpha < 1.0f) {
		DWORD style = ::GetWindowLongW(ud->native_handle, GWL_EXSTYLE) | WS_EX_LAYERED;
		::SetWindowLongW(ud->native_handle, GWL_EXSTYLE, style);
		::SetLayeredWindowAttributes(ud->native_handle, 0, (BYTE)(255 * alpha), LWA_ALPHA);
	}
	else {
		DWORD style = ::GetWindowLongW(ud->native_handle, GWL_EXSTYLE) & ~WS_EX_LAYERED;
		::SetWindowLongW(ud->native_handle, GWL_EXSTYLE, style);
	}
}

float GetDpiScaleForMonitor(void* monitor) {
	typedef HRESULT(WINAPI* PFN_GetDpiForMonitor)(HMONITOR, UINT, UINT*, UINT*);
	HINSTANCE shcore_dll = ::LoadLibraryA("shcore.dll");
	if (shcore_dll) {
		PFN_GetDpiForMonitor GetDpiForMonitorFn = (PFN_GetDpiForMonitor)::GetProcAddress(shcore_dll, "GetDpiForMonitor");
		if (GetDpiForMonitorFn) {
			UINT xdpi = 96;
			UINT ydpi = 96;
			GetDpiForMonitorFn((HMONITOR)monitor, 0 /*MDT_EFFECTIVE_DPI*/, &xdpi, &ydpi);
			return xdpi / 96.0f;
		}
	}
	const HDC dc = ::GetDC(NULL);
	UINT xdpi = ::GetDeviceCaps(dc, LOGPIXELSX);
	UINT ydpi = ::GetDeviceCaps(dc, LOGPIXELSY);
	::ReleaseDC(NULL, dc);
	return xdpi / 96.0f;
}

static float platformGetWindowDpiScale(ImGuiViewport* viewport) {
	PlatformViewport* ud = (PlatformViewport*)viewport->PlatformUserData;
	HMONITOR monitor = ::MonitorFromWindow((HWND)ud->native_handle, MONITOR_DEFAULTTONEAREST);
	return GetDpiScaleForMonitor(monitor);
}

static void platformOnChangedViewport(ImGuiViewport* viewport) {
}

static void
get_xy(LPARAM lParam, int* x, int* y) {
	*x = (short)(lParam & 0xffff);
	*y = (short)((lParam >> 16) & 0xffff);
}

static void
get_screen_xy(HWND hwnd, LPARAM lParam, int* x, int* y) {
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

static void platformImGuiWindowFunction(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
	if (!ImGui::GetCurrentContext())
		return;
	ImGuiIO& io = ImGui::GetIO();
	switch (message) {
	case WM_MOUSEWHEEL:
		io.MouseWheel += (float)GET_WHEEL_DELTA_WPARAM(wParam) / (float)WHEEL_DELTA;
		return;
	case WM_MOUSEHWHEEL:
		io.MouseWheelH += (float)GET_WHEEL_DELTA_WPARAM(wParam) / (float)WHEEL_DELTA;
		return;
	case WM_LBUTTONDOWN:
		io.MouseDown[0] = true;
		return;
	case WM_LBUTTONUP:
		io.MouseDown[0] = false;
		return;
	case WM_RBUTTONDOWN:
		io.MouseDown[1] = true;
		return;
	case WM_RBUTTONUP:
		io.MouseDown[1] = false;
		return;
	case WM_MBUTTONDOWN:
		io.MouseDown[2] = true;
		return;
	case WM_MBUTTONUP:
		io.MouseDown[2] = false;
		return;
	case WM_KEYDOWN:
		if (wParam >= 0 && wParam < 256) {
			io.KeysDown[wParam] = true;
		}
		return;
	case WM_KEYUP:
		if (wParam >= 0 && wParam < 256) {
			io.KeysDown[wParam] = false;
		}
		return;
	case WM_CHAR:
		if (wParam > 0 && wParam < 0x10000) {
			io.AddInputCharacterUTF16((unsigned short)wParam);
		}
		return;
	}
}

static void platformEventWindowFunction(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
	struct window_callback* cb = NULL;
	int x, y;
	switch (message) {
	case WM_CREATE: {
		LPCREATESTRUCTA cs = (LPCREATESTRUCTA)lParam;
		cb = (struct window_callback*)(cs->lpCreateParams);
		SetWindowLongPtr(hWnd, GWLP_USERDATA, (LONG_PTR)cb);
		return;
	}
	case WM_MOUSEMOVE:
		cb = (struct window_callback*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		get_xy(lParam, &x, &y);
		if ((wParam & (MK_LBUTTON | MK_RBUTTON | MK_MBUTTON)) == 0) {
			window_event_mouse(cb, x, y, 0, 2);
		}
		else {
			if (wParam & MK_LBUTTON) {
				window_event_mouse(cb, x, y, 1, 2);
			}
			if (wParam & MK_RBUTTON) {
				window_event_mouse(cb, x, y, 2, 2);
			}
			if (wParam & MK_MBUTTON) {
				window_event_mouse(cb, x, y, 3, 2);
			}
		}
		return;
	case WM_MOUSEWHEEL: {
		cb = (struct window_callback*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		get_screen_xy(hWnd, lParam, &x, &y);
		float delta = (float)GET_WHEEL_DELTA_WPARAM(wParam) / (float)WHEEL_DELTA;
		window_event_mouse_wheel(cb, x, y, delta);
		return;
	}
	case WM_LBUTTONDOWN:
	case WM_LBUTTONUP:
		cb = (struct window_callback*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		get_xy(lParam, &x, &y);
		window_event_mouse(cb, x, y, 1, (message == WM_LBUTTONDOWN) ? 1 : 3);
		return;
	case WM_RBUTTONDOWN:
	case WM_RBUTTONUP:
		cb = (struct window_callback*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		get_xy(lParam, &x, &y);
		window_event_mouse(cb, x, y, 2, (message == WM_RBUTTONDOWN) ? 1 : 3);
		return;
	case WM_MBUTTONDOWN:
	case WM_MBUTTONUP:
		cb = (struct window_callback*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		get_xy(lParam, &x, &y);
		window_event_mouse(cb, x, y, 3, (message == WM_MBUTTONDOWN) ? 1 : 3);
		return;
	case WM_KEYDOWN:
	case WM_KEYUP: {
		cb = (struct window_callback*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		int press = (message == WM_KEYUP ? 0 : (
			(lParam & (1 << 30)) ? 2 : 1
			));
		int key = (int)wParam;
		uint8_t state = get_keystate(lParam);
		window_event_keyboard(cb, key, state, press);
		return;
	}
	case WM_DROPFILES: {
		cb = (struct window_callback*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		HDROP drop = (HDROP)wParam;
		UINT file_count = DragQueryFile(drop, 0xFFFFFFFF, NULL, 0);
		char** paths = (char**)malloc(sizeof(char*) * file_count);
		int* path_counts = (int*)malloc(sizeof(int) * file_count);
		int count = file_count;
		for (UINT i = 0; i < file_count; i++) {
			path_counts[i] = 0;
			paths[i] = NULL;
			WCHAR* str_w = (WCHAR*)malloc(sizeof(WCHAR) * MAX_DROP_PATH);
			UINT size_w = DragQueryFileW(drop, i, str_w, MAX_DROP_PATH);
			if (str_w != NULL && size_w > 0) {
				int len_a = WideCharToMultiByte(CP_UTF8, 0, str_w, size_w, NULL, 0, NULL, NULL);
				if (len_a > 0) {
					paths[i] = (char*)malloc(sizeof(char) * (len_a + 1));
					if (paths[i] != NULL) {
						int out_len = WideCharToMultiByte(CP_UTF8, 0, str_w, size_w, paths[i], len_a, NULL, NULL);
						path_counts[i] = out_len;
					}
				}
			}
			free(str_w);
		}
		window_event_dropfiles(cb, count, paths, path_counts);
		for (UINT i = 0; i < file_count; i++) {
			if (paths[i] != NULL)
				free(paths[i]);
		}
		free(paths);
		free(path_counts);
		return;
	}
	case WM_USER_WINDOW_SETCURSOR:
		SetCursor(LoadCursor(NULL, (LPTSTR)lParam));
		return;
	}
}

static LRESULT CALLBACK platformViewportWindowFunction(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
	platformImGuiWindowFunction(hWnd, message, wParam, lParam);
	platformEventWindowFunction(hWnd, message, wParam, lParam);
	if (ImGuiViewport* viewport = ImGui::FindViewportByPlatformHandle((void*)hWnd)) {
		switch (message) {
		case WM_CLOSE:
			viewport->PlatformRequestClose = true;
			return 0;
		case WM_MOVE:
			viewport->PlatformRequestMove = true;
			break;
		case WM_SIZE:
			viewport->PlatformRequestResize = true;
			break;
		case WM_MOUSEACTIVATE:
			if (viewport->Flags & ImGuiViewportFlags_NoFocusOnClick)
				return MA_NOACTIVATE;
			break;
		case WM_NCHITTEST:if (viewport->Flags & ImGuiViewportFlags_NoInputs)
				return HTTRANSPARENT;
			break;
		}
	}
	return DefWindowProcW(hWnd, message, wParam, lParam);
}

static LRESULT CALLBACK platformMainViewportWindowFunction(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
	platformImGuiWindowFunction(hWnd, message, wParam, lParam);
	platformEventWindowFunction(hWnd, message, wParam, lParam);
	switch (message) {
	case WM_DESTROY: {
		struct window_callback* cb = (struct window_callback*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		window_event_exit(cb);
		PostQuitMessage(0);
		return 0;
	}
	case WM_SIZE: {
		struct window_callback* cb = (struct window_callback*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		switch (wParam) {
		case SIZE_MINIMIZED:
			window_event_size(cb, LOWORD(lParam), HIWORD(lParam), 1);
			break;
		case SIZE_MAXIMIZED:
			window_event_size(cb, LOWORD(lParam), HIWORD(lParam), 2);
			break;
		default:
			window_event_size(cb, LOWORD(lParam), HIWORD(lParam), 0);
			break;
		}
		break;
	}
	default:
		break;
	}
	return DefWindowProcW(hWnd, message, wParam, lParam);
}

static BOOL CALLBACK enumMonitors(HMONITOR monitor, HDC, LPRECT, LPARAM) {
	MONITORINFO info = { 0 };
	info.cbSize = sizeof(MONITORINFO);
	if (!::GetMonitorInfo(monitor, &info))
		return TRUE;
	ImGuiPlatformMonitor imgui_monitor;
	imgui_monitor.MainPos = ImVec2((float)info.rcMonitor.left, (float)info.rcMonitor.top);
	imgui_monitor.MainSize = ImVec2((float)(info.rcMonitor.right - info.rcMonitor.left), (float)(info.rcMonitor.bottom - info.rcMonitor.top));
	imgui_monitor.WorkPos = ImVec2((float)info.rcWork.left, (float)info.rcWork.top);
	imgui_monitor.WorkSize = ImVec2((float)(info.rcWork.right - info.rcWork.left), (float)(info.rcWork.bottom - info.rcWork.top));
	imgui_monitor.DpiScale = GetDpiScaleForMonitor(monitor);
	ImGuiPlatformIO& io = ImGui::GetPlatformIO();
	if (info.dwFlags & MONITORINFOF_PRIMARY)
		io.Monitors.push_front(imgui_monitor);
	else
		io.Monitors.push_back(imgui_monitor);
	return TRUE;
}

static void updateMousePos() {
	ImGuiIO& io = ImGui::GetIO();

	if (io.WantSetMousePos) {
		POINT pos = { (int)io.MousePos.x, (int)io.MousePos.y };
		if ((io.ConfigFlags & ImGuiConfigFlags_ViewportsEnable) == 0)
			::ClientToScreen(g_main_window, &pos);
		::SetCursorPos(pos.x, pos.y);
	}
	io.MousePos = ImVec2(-FLT_MAX, -FLT_MAX);
	io.MouseHoveredViewport = 0;
	POINT mouse_screen_pos;
	if (!::GetCursorPos(&mouse_screen_pos))
		return;
	if (HWND focused_hwnd = ::GetForegroundWindow()) {
		if (::IsChild(focused_hwnd, g_main_window))
			focused_hwnd = g_main_window;
		if (io.ConfigFlags & ImGuiConfigFlags_ViewportsEnable) {
			if (ImGui::FindViewportByPlatformHandle((void*)focused_hwnd) != NULL)
				io.MousePos = ImVec2((float)mouse_screen_pos.x, (float)mouse_screen_pos.y);
		}
		else {
			if (focused_hwnd == g_main_window) {
				POINT mouse_client_pos = mouse_screen_pos;
				::ScreenToClient(focused_hwnd, &mouse_client_pos);
				io.MousePos = ImVec2((float)mouse_client_pos.x, (float)mouse_client_pos.y);
			}
		}
	}

	if (HWND hovered_hwnd = ::WindowFromPoint(mouse_screen_pos))
		if (ImGuiViewport* viewport = ImGui::FindViewportByPlatformHandle((void*)hovered_hwnd))
			if ((viewport->Flags & ImGuiViewportFlags_NoInputs) == 0) 
				io.MouseHoveredViewport = viewport->ID;
}

void platformNewFrame() {
	ImGuiIO& io = ImGui::GetIO();
	RECT rect;
	::GetClientRect(g_main_window, &rect);
	io.DisplaySize = ImVec2((float)(rect.right - rect.left), (float)(rect.bottom - rect.top));

	updateMousePos();
	ImGuiMouseCursor cursor_type = io.MouseDrawCursor ? ImGuiMouseCursor_None : ImGui::GetMouseCursor();
	if (io.WantCaptureMouse && !(io.ConfigFlags & ImGuiConfigFlags_NoMouseCursorChange)) {
		set_cursor(cursor_type);
	}

	io.KeyCtrl = (::GetKeyState(VK_CONTROL) & 0x8000) != 0;
	io.KeyShift = (::GetKeyState(VK_SHIFT) & 0x8000) != 0;
	io.KeyAlt = (::GetKeyState(VK_MENU) & 0x8000) != 0;
	io.KeySuper = false;
}

void platformDestroy() {
	ImGuiViewport* viewport = ImGui::GetMainViewport();
	PlatformViewport* ud = (PlatformViewport*)viewport->PlatformUserData;
	delete ud;
	viewport->PlatformUserData = nullptr;
}

static bool platformCreateMainWindow(lua_State* L, int w, int h) {
	struct window_callback* cb = window_get_callback(L);

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
	wndclass.lpfnWndProc = platformMainViewportWindowFunction;
	wndclass.hInstance = GetModuleHandleW(0);
	wndclass.hIcon = LoadIcon(NULL, IDI_APPLICATION);
	wndclass.hCursor = LoadCursor(NULL, IDC_ARROW);
	wndclass.lpszClassName = L"ImGui Main Viewport";
	wndclass.hIconSm = LoadIcon(NULL, IDI_APPLICATION);
	RegisterClassExW(&wndclass);

	HWND window = CreateWindowExW(0, L"ImGui Main Viewport", NULL,
		WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, 0,
		rect.right - rect.left, rect.bottom - rect.top,
		0, 0,
		GetModuleHandleW(0),
		cb);
	if (!window) {
		return false;
	}
	g_main_window = window;
	ImGuiViewport* main_viewport = ImGui::GetMainViewport();
	PlatformViewport* ud = new PlatformViewport();
	ud->native_handle = g_main_window;
	ud->owned = false;
	main_viewport->PlatformUserData = ud;
	main_viewport->PlatformHandle = (void*)g_main_window;

	RECT r;
	GetClientRect(window, &r);
	window_event_init(cb, window, 0, r.right - r.left, r.bottom - r.top);

	DragAcceptFiles(window, TRUE);
	ShowWindow(window, SW_SHOWDEFAULT);
	UpdateWindow(window);

	return true;
}

bool platformCreate(lua_State* L, int w, int h) {
	ImGuiIO& io = ImGui::GetIO();
	ImGuiPlatformIO& platform_io = ImGui::GetPlatformIO();
	ImGuiStyle& style = ImGui::GetStyle();

	io.BackendFlags |= ImGuiBackendFlags_HasMouseCursors;
	io.BackendFlags |= ImGuiBackendFlags_PlatformHasViewports;

	style.WindowRounding = 0.0f;
	style.Colors[ImGuiCol_WindowBg].w = 1.0f;

	platform_io.Platform_SetImeInputPos = platformSetImeInputPos;
	platform_io.Platform_CreateWindow = platformCreateWindow;
	platform_io.Platform_DestroyWindow = platformDestroyWindow;
	platform_io.Platform_ShowWindow = platformShowWindow;
	platform_io.Platform_UpdateWindow = platformUpdateWindow;
	platform_io.Platform_GetWindowPos = platformGetWindowPos;
	platform_io.Platform_SetWindowPos = platformSetWindowPos;
	platform_io.Platform_GetWindowSize = platformGetWindowSize;
	platform_io.Platform_SetWindowSize = platformSetWindowSize;
	platform_io.Platform_SetWindowFocus = platformSetWindowFocus;
	platform_io.Platform_GetWindowFocus = platformGetWindowFocus;
	platform_io.Platform_GetWindowMinimized = platformGetWindowMinimized;
	platform_io.Platform_SetWindowTitle = platformSetWindowTitle;
	platform_io.Platform_SetWindowAlpha = platformSetWindowAlpha;
	platform_io.Platform_GetWindowDpiScale = platformGetWindowDpiScale;
	platform_io.Platform_OnChangedViewport = platformOnChangedViewport;

	platform_io.Monitors.resize(0);
	::EnumDisplayMonitors(NULL, NULL, enumMonitors, NULL);

	if (!platformCreateMainWindow(L, w, h)) {
		return false;
	}

	WNDCLASSEXW wcex;
	wcex.cbSize = sizeof(WNDCLASSEXW);
	wcex.style = CS_HREDRAW | CS_VREDRAW;
	wcex.lpfnWndProc = platformViewportWindowFunction;
	wcex.cbClsExtra = 0;
	wcex.cbWndExtra = 0;
	wcex.hInstance = ::GetModuleHandle(NULL);
	wcex.hIcon = NULL;
	wcex.hCursor = NULL;
	wcex.hbrBackground = (HBRUSH)(COLOR_BACKGROUND + 1);
	wcex.lpszMenuName = NULL;
	wcex.lpszClassName = L"ImGui Platform";
	wcex.hIconSm = NULL;
	::RegisterClassEx(&wcex);

	io.KeyMap[ImGuiKey_Tab] = VK_TAB;
	io.KeyMap[ImGuiKey_LeftArrow] = VK_LEFT;
	io.KeyMap[ImGuiKey_RightArrow] = VK_RIGHT;
	io.KeyMap[ImGuiKey_UpArrow] = VK_UP;
	io.KeyMap[ImGuiKey_DownArrow] = VK_DOWN;
	io.KeyMap[ImGuiKey_PageUp] = VK_PRIOR;
	io.KeyMap[ImGuiKey_PageDown] = VK_NEXT;
	io.KeyMap[ImGuiKey_Home] = VK_HOME;
	io.KeyMap[ImGuiKey_End] = VK_END;
	io.KeyMap[ImGuiKey_Insert] = VK_INSERT;
	io.KeyMap[ImGuiKey_Delete] = VK_DELETE;
	io.KeyMap[ImGuiKey_Backspace] = VK_BACK;
	io.KeyMap[ImGuiKey_Space] = VK_SPACE;
	io.KeyMap[ImGuiKey_Enter] = VK_RETURN;
	io.KeyMap[ImGuiKey_Escape] = VK_ESCAPE;
	io.KeyMap[ImGuiKey_KeyPadEnter] = VK_RETURN;
	io.KeyMap[ImGuiKey_A] = 'A';
	io.KeyMap[ImGuiKey_C] = 'C';
	io.KeyMap[ImGuiKey_V] = 'V';
	io.KeyMap[ImGuiKey_X] = 'X';
	io.KeyMap[ImGuiKey_Y] = 'Y';
	io.KeyMap[ImGuiKey_Z] = 'Z';

	return true;
}

void platformMainLoop(lua_State* L) {
	struct window_callback*  cb = window_get_callback(L);
	MSG msg;
	for (;;) {
		if (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
			if (msg.message == WM_QUIT)
				break;
			TranslateMessage(&msg);
			DispatchMessageW(&msg);
		}
		else {
			window_event_update(cb);
			Sleep(0);
		}
	}
	UnregisterClassW(L"ImGui Main Viewport", GetModuleHandleW(0));
}
