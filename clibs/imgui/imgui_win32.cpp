#include <imgui.h>
#include <Windows.h>
#include <mingw/mingw_window.h>

void init_cursor() {
    ImGuiIO& io = ImGui::GetIO();
    io.BackendFlags |= ImGuiBackendFlags_HasMouseCursors;
}

void set_cursor(ImGuiMouseCursor im_cursor) {
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
	case ImGuiMouseCursor_None:      cursor = NULL; break;
	}
	ImGuiViewport* main_viewport = ImGui::GetMainViewport();
	HWND  window = (HWND)(main_viewport->PlatformHandle);
	if (window != NULL)
		PostMessage(window, WM_USER_WINDOW_SETCURSOR, NULL, (LPARAM)cursor);
	else if (cursor != NULL)
		::SetCursor(::LoadCursor(NULL, cursor));
	else
		::SetCursor(NULL);
}
#if defined(__MINGW32__)

#include <Windows.h>
#include <imm.h>

static void 
ImGui_ImplWin32_SetImeInputPos(ImGuiViewport* viewport, ImVec2 pos)
{
	COMPOSITIONFORM cf = { CFS_FORCE_POSITION,{ (LONG)(pos.x - viewport->Pos.x), (LONG)(pos.y - viewport->Pos.y) },{ 0, 0, 0, 0 } };
	if (HWND hwnd = (HWND)viewport->PlatformHandle)
		if (HIMC himc = ::ImmGetContext(hwnd))
		{
			::ImmSetCompositionWindow(himc, &cf);
			::ImmReleaseContext(hwnd, himc);
		}
}

#endif
#if defined(_WIN32) && !defined(IMGUI_DISABLE_WIN32_FUNCTIONS) && !defined(IMGUI_DISABLE_WIN32_DEFAULT_IME_FUNCTIONS) && !defined(__GNUC__)
#define HAS_WIN32_IME   1
#include <imm.h>
#ifdef _MSC_VER
#pragma comment(lib, "imm32")
#endif
static void ImGui_ImplWin32_SetImeInputPos(ImGuiViewport * viewport, ImVec2 pos)
{
	COMPOSITIONFORM cf = { CFS_FORCE_POSITION,{ (LONG)(pos.x - viewport->Pos.x), (LONG)(pos.y - viewport->Pos.y) },{ 0, 0, 0, 0 } };
	if (HWND hwnd = (HWND)viewport->PlatformHandle)
		if (HIMC himc = ::ImmGetContext(hwnd))
		{
			::ImmSetCompositionWindow(himc, &cf);
			::ImmReleaseContext(hwnd, himc);
		}
}
#else
#define HAS_WIN32_IME   0
#endif

void init_ime(void* window) {
	ImGuiViewport* main_viewport = ImGui::GetMainViewport();
	main_viewport->PlatformHandle = window;
	//io.ImeWindowHandle = window;
	ImGuiPlatformIO& platform_io = ImGui::GetPlatformIO();
#if HAS_WIN32_IME
	platform_io.Platform_SetImeInputPos = ImGui_ImplWin32_SetImeInputPos;
#endif

#if defined(__MINGW32__)
	/*ImGuiIO& io = ImGui::GetIO();
	io.ImeSetInputScreenPosFn = ImeSetInputScreenPosFn_DefaultImpl;*/
	platform_io.Platform_SetImeInputPos = ImGui_ImplWin32_SetImeInputPos;
#endif
}
