#include <ImGui.h>
#include <Windows.h>
#include <oleidl.h>
#include <memory>
#include <string>
#include <string_view>
#include <vector>
#include <examples/imgui_impl_win32.h>
#include "../imgui_window.h"
#include "../imgui_platform.h"

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
		struct window_callback* cb = (struct window_callback*)GetWindowLongPtr(m_window, GWLP_USERDATA);
		window_event_dropfiles(cb, m_files);
		m_files.clear();
		*pdwEffect &= DROPEFFECT_COPY;
		return S_OK;
	}
	void Register(HWND window) {
		m_window = window;
		RegisterDragDrop(m_window, this);
	}
	void Revoke() {
		RevokeDragDrop(m_window);
	}
};

DropManager g_dropmanager;

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
	case WM_DESTROY:
		PostQuitMessage(0);
		return 0;
	case WM_SIZE: {
		struct window_callback* cb = (struct window_callback*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
		window_event_size(cb, LOWORD(lParam), HIWORD(lParam));
		break;
	}
	default:
		break;
	}
	return DefWindowProcW(hWnd, message, wParam, lParam);
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
	ShowWindow(window, SW_SHOWDEFAULT);
	UpdateWindow(window);
	return window;
}

void* platformCreate(lua_State* L, int w, int h) {
	if (FAILED(OleInitialize(NULL))) {
		return nullptr;
	}
	HWND window = platformCreateMainWindow(L, w, h);
	if (!window) {
		return nullptr;
	}
	g_dropmanager.Register(window);
	ImGui_ImplWin32_Init(window);
	return window;
}

void platformDestroy() {
	g_dropmanager.Revoke();
	OleUninitialize();
	ImGui_ImplWin32_Shutdown();
	UnregisterClassW(L"ImGui Host Viewport", GetModuleHandleW(NULL));
}

bool platformNewFrame() {
	MSG msg;
	for (;;) {
		if (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
			if (msg.message == WM_QUIT)
				return false;
			TranslateMessage(&msg);
			DispatchMessageW(&msg);
		}
		else {
			ImGui_ImplWin32_NewFrame();
			return true;
		}
	}
}
