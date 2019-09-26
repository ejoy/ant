#include <imgui.h>
#include <Windows.h>
#include <imm.h>
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

void update_mousepos() 
{
	ImGuiIO& io = ImGui::GetIO();
	ImGuiViewport* main_viewport = ImGui::GetMainViewport();
	HWND main_window = (HWND)main_viewport->PlatformHandle;

	// Set OS mouse position if requested (rarely used, only when ImGuiConfigFlags_NavEnableSetMousePos is enabled by user)
	// (When multi-viewports are enabled, all imgui positions are same as OS positions)
	if (io.WantSetMousePos)
	{
		POINT pos = { (int)io.MousePos.x, (int)io.MousePos.y };
		if ((io.ConfigFlags & ImGuiConfigFlags_ViewportsEnable) == 0)
			::ClientToScreen(main_window, &pos);
		::SetCursorPos(pos.x, pos.y);
	}

	io.MousePos = ImVec2(-FLT_MAX, -FLT_MAX);
	io.MouseHoveredViewport = 0;

	// Set imgui mouse position
	POINT mouse_screen_pos;
	if (!::GetCursorPos(&mouse_screen_pos))
		return;
	if (HWND focused_hwnd = ::GetForegroundWindow())
	{
		if (::IsChild(focused_hwnd, main_window))
			focused_hwnd = main_window;
		if (io.ConfigFlags & ImGuiConfigFlags_ViewportsEnable)
		{
			// Multi-viewport mode: mouse position in OS absolute coordinates (io.MousePos is (0,0) when the mouse is on the upper-left of the primary monitor)
			// This is the position you can get with GetCursorPos(). In theory adding viewport->Pos is also the reverse operation of doing ScreenToClient().
			if (ImGui::FindViewportByPlatformHandle((void*)focused_hwnd) != NULL)
				io.MousePos = ImVec2((float)mouse_screen_pos.x, (float)mouse_screen_pos.y);

		}
		else
		{
			// Single viewport mode: mouse position in client window coordinates (io.MousePos is (0,0) when the mouse is on the upper-left corner of the app window.)
			// This is the position you can get with GetCursorPos() + ScreenToClient() or from WM_MOUSEMOVE.
			if (focused_hwnd == main_window)
			{
				POINT mouse_client_pos = mouse_screen_pos;
				::ScreenToClient(focused_hwnd, &mouse_client_pos);
				io.MousePos = ImVec2((float)mouse_client_pos.x, (float)mouse_client_pos.y);
			}
			else
			{
				POINT mouse_client_pos = mouse_screen_pos;
				::ScreenToClient(main_window, &mouse_client_pos);
				io.MousePos = ImVec2((float)mouse_client_pos.x, (float)mouse_client_pos.y);
			}
		}
	}
}

static void ImGui_ImplWin32_SetImeInputPos(ImGuiViewport * viewport, ImVec2 pos) {
	COMPOSITIONFORM cf = { CFS_FORCE_POSITION,{ (LONG)(pos.x - viewport->Pos.x), (LONG)(pos.y - viewport->Pos.y) },{ 0, 0, 0, 0 } };
	if (HWND hwnd = (HWND)viewport->PlatformHandle)
		if (HIMC himc = ::ImmGetContext(hwnd)) {
			::ImmSetCompositionWindow(himc, &cf);
			::ImmReleaseContext(hwnd, himc);
		}
}

void init_ime(void* window) {
	ImGuiViewport* main_viewport = ImGui::GetMainViewport();
	main_viewport->PlatformHandle = window;
	ImGuiPlatformIO& platform_io = ImGui::GetPlatformIO();
	platform_io.Platform_SetImeInputPos = ImGui_ImplWin32_SetImeInputPos;
}
