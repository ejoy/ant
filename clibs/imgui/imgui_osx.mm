#include <imgui.h>
#include <Cocoa/Cocoa.h>

void set_cursor(ImGuiMouseCursor cursor) {
    switch (cursor) {
    default:
    case ImGuiMouseCursor_Arrow:      [[NSCursor arrowCursor] set];           [NSCursor unhide]; break;
    case ImGuiMouseCursor_TextInput:  [[NSCursor IBeamCursor] set];           [NSCursor unhide]; break;
    case ImGuiMouseCursor_ResizeNESW:
    case ImGuiMouseCursor_ResizeNWSE:
    case ImGuiMouseCursor_ResizeAll:  [[NSCursor closedHandCursor] set];      [NSCursor unhide]; break;
    case ImGuiMouseCursor_ResizeEW:   [[NSCursor resizeLeftRightCursor] set]; [NSCursor unhide]; break;
    case ImGuiMouseCursor_ResizeNS:   [[NSCursor resizeUpDownCursor] set];    [NSCursor unhide]; break;
    case ImGuiMouseCursor_Hand:       [[NSCursor pointingHandCursor] set];    [NSCursor unhide]; break;
    case ImGuiMouseCursor_None:       [NSCursor hide]; break;
    }
}
