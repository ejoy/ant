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
ImeSetInputScreenPosFn_DefaultImpl(int x, int y) {
    if (HWND hwnd = (HWND)ImGui::GetIO().ImeWindowHandle)
        if (HIMC himc = ::ImmGetContext(hwnd)) {
            COMPOSITIONFORM cf;
            cf.ptCurrentPos.x = x;
            cf.ptCurrentPos.y = y;
            cf.dwStyle = CFS_FORCE_POSITION;
            ::ImmSetCompositionWindow(himc, &cf);
            ::ImmReleaseContext(hwnd, himc);
        }
}

#endif

void init_ime(void* window) {
    ImGuiIO& io = ImGui::GetIO();
	io.ImeWindowHandle = window;
#if defined(__MINGW32__)
    io.ImeSetInputScreenPosFn = ImeSetInputScreenPosFn_DefaultImpl;
#endif
}
