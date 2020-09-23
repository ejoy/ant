#include <ImGui.h>
#include <Windows.h>
#include <imm.h>
#include "../imgui_window.h"
#include "../imgui_platform.h"
#include <examples/imgui_impl_win32.h>

#define MAX_DROP_PATH 255*3

// Forward declare message handler from imgui_impl_win32.cpp
extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

static LRESULT CALLBACK platformMainViewportWindowFunction(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
	if (ImGui_ImplWin32_WndProcHandler(hWnd, message, wParam, lParam)) {
		return true;
	}
	struct window_callback* cb = NULL;
	switch (message) {
	case WM_CREATE: {
		LPCREATESTRUCTA cs = (LPCREATESTRUCTA)lParam;
		cb = (struct window_callback*)(cs->lpCreateParams);
		SetWindowLongPtr(hWnd, GWLP_USERDATA, (LONG_PTR)cb);
		break;
	}
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
		break;
	}
	default:
		break;
	}
	return DefWindowProcW(hWnd, message, wParam, lParam);
}

void platformNewFrame() {
	ImGui_ImplWin32_NewFrame();
}

void platformDestroy() {
	ImGui_ImplWin32_Shutdown();
	UnregisterClassW(L"ImGui Host Viewport", GetModuleHandleW(NULL));
}

static HWND platformCreateMainWindow(lua_State* L, int w, int h) {
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
	wndclass.style = CS_HREDRAW | CS_VREDRAW;
	wndclass.lpfnWndProc = platformMainViewportWindowFunction;
	wndclass.hInstance = GetModuleHandleW(NULL);
	wndclass.hIcon = LoadIconW(NULL, IDI_APPLICATION);
	wndclass.hCursor = LoadCursorW(NULL, IDC_ARROW);
	wndclass.lpszClassName = L"ImGui Host Viewport";
	wndclass.hIconSm = LoadIconW(NULL, IDI_APPLICATION);
	RegisterClassExW(&wndclass);

	HWND window = CreateWindowExW(0, L"ImGui Host Viewport", NULL,
		WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, 0,
		rect.right - rect.left, rect.bottom - rect.top,
		0, 0,
		GetModuleHandleW(NULL),
		cb);
	if (!window) {
		return NULL;
	}

	RECT r;
	GetClientRect(window, &r);
	window_event_init(cb, window, 0, r.right - r.left, r.bottom - r.top);

	DragAcceptFiles(window, TRUE);
	ShowWindow(window, SW_SHOWDEFAULT);
	UpdateWindow(window);

	return window;
}

bool platformCreate(lua_State* L, int w, int h) {
	HWND window = platformCreateMainWindow(L, w, h);
	if (!window) {
		return false;
	}
	ImGui_ImplWin32_Init(window);
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
}
