#include <imgui.h>
#include <Cocoa/Cocoa.h>

static NSCursor*      g_MouseCursors[ImGuiMouseCursor_COUNT] = { 0 };
static bool           g_MouseCursorHidden = false;

@interface NSCursor()
+ (id)_windowResizeNorthWestSouthEastCursor;
+ (id)_windowResizeNorthEastSouthWestCursor;
+ (id)_windowResizeNorthSouthCursor;
+ (id)_windowResizeEastWestCursor;
+ (id)_crosshairCursor;
@end

void init_cursor() {
    g_MouseCursorHidden = false;
    g_MouseCursors[ImGuiMouseCursor_Arrow] = [NSCursor arrowCursor];
    g_MouseCursors[ImGuiMouseCursor_TextInput] = [NSCursor IBeamCursor];
    g_MouseCursors[ImGuiMouseCursor_ResizeAll] = [NSCursor respondsToSelector:@selector(_crosshairCursor)]
        ? [NSCursor _crosshairCursor]
        : [NSCursor closedHandCursor];
    g_MouseCursors[ImGuiMouseCursor_Hand] = [NSCursor pointingHandCursor];
    g_MouseCursors[ImGuiMouseCursor_ResizeNS] = [NSCursor respondsToSelector:@selector(_windowResizeNorthSouthCursor)]
        ? [NSCursor _windowResizeNorthSouthCursor]
        : [NSCursor resizeUpDownCursor];
    g_MouseCursors[ImGuiMouseCursor_ResizeEW] = [NSCursor respondsToSelector:@selector(_windowResizeEastWestCursor)]
        ? [NSCursor _windowResizeEastWestCursor]
        : [NSCursor resizeLeftRightCursor];
    g_MouseCursors[ImGuiMouseCursor_ResizeNESW] = [NSCursor respondsToSelector:@selector(_windowResizeNorthEastSouthWestCursor)]
        ? [NSCursor _windowResizeNorthEastSouthWestCursor]
        : [NSCursor closedHandCursor];
    g_MouseCursors[ImGuiMouseCursor_ResizeNWSE] = [NSCursor respondsToSelector:@selector(_windowResizeNorthWestSouthEastCursor)]
        ? [NSCursor _windowResizeNorthWestSouthEastCursor]
        : [NSCursor closedHandCursor];
}

void set_cursor(ImGuiMouseCursor cursor) {
    if (cursor == ImGuiMouseCursor_None) {
        if (!g_MouseCursorHidden) {
            g_MouseCursorHidden = true;
            [NSCursor hide];
        }
    }
    else {
        [g_MouseCursors[g_MouseCursors[cursor]? cursor: ImGuiMouseCursor_Arrow] set];
        if (g_MouseCursorHidden) {
            g_MouseCursorHidden = false;
            [NSCursor unhide];
        }
    }
}
