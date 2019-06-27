#include <imgui.h>
#include <Windows.h>

void init_cursor() {
    ImGuiIO& io = ImGui::GetIO();
    io.BackendFlags |= ImGuiBackendFlags_HasMouseCursors;
}

void set_cursor(ImGuiMouseCursor cursor) {
    switch (cursor) {
    default: [[fallthrough]];
    case ImGuiMouseCursor_Arrow:      ::SetCursor(::LoadCursor(NULL, IDC_ARROW));    break;
    case ImGuiMouseCursor_TextInput:  ::SetCursor(::LoadCursor(NULL, IDC_IBEAM));    break;
    case ImGuiMouseCursor_ResizeAll:  ::SetCursor(::LoadCursor(NULL, IDC_SIZEALL));  break;
    case ImGuiMouseCursor_ResizeEW:   ::SetCursor(::LoadCursor(NULL, IDC_SIZEWE));   break;
    case ImGuiMouseCursor_ResizeNS:   ::SetCursor(::LoadCursor(NULL, IDC_SIZENS));   break;
    case ImGuiMouseCursor_ResizeNESW: ::SetCursor(::LoadCursor(NULL, IDC_SIZENESW)); break;
    case ImGuiMouseCursor_ResizeNWSE: ::SetCursor(::LoadCursor(NULL, IDC_SIZENWSE)); break;
    case ImGuiMouseCursor_Hand:       ::SetCursor(::LoadCursor(NULL, IDC_HAND));     break;
    case ImGuiMouseCursor_None:       ::SetCursor(NULL); break;
    }
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
