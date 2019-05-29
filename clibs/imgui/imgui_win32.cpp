#include <imgui.h>
#include <Windows.h>

void init_cursor() {
    // empty
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
