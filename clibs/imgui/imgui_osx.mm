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
    ImGuiIO& io = ImGui::GetIO();
    io.BackendFlags |= ImGuiBackendFlags_HasMouseCursors;

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


static const NSRange kEmptyRange = { NSNotFound, 0 };

@interface IMEView : NSView <NSTextInputClient> {
    int m_x;
    int m_y;
}
- (void)setPosX:(int)x setPosY:(int)y;
@end

@implementation IMEView

- (void)setPosX:(int)x setPosY:(int)y {
    m_x = x;
    m_y = y;
}

- (void)insertText:(id)aString replacementRange:(NSRange)replacementRange {
    NSString* characters = [aString isKindOfClass: [NSAttributedString class]]
        ? [aString string]
        : aString;
    ImGuiIO& io = ImGui::GetIO();
    NSUInteger len = [characters length];
    for (NSUInteger i = 0; i < len; ++i) {
        const unichar codepoint = [characters characterAtIndex:i];
        if ((codepoint & 0xff00) == 0xf700)
            continue;
        io.AddInputCharacter(codepoint);
    }
}

- (BOOL)hasMarkedText {
    return false;
}

- (NSRange)markedRange {
    return kEmptyRange;
}

- (NSRange)selectedRange {
    return kEmptyRange;
}

- (void)setMarkedText:(id)string selectedRange:(NSRange)selectedRange replacementRange:(NSRange)replacementRange {
}

- (void)unmarkText {
}

- (NSRect)firstRectForCharacterRange:(NSRange)aRange actualRange:(NSRangePointer)actualRange {
    if (actualRange) {
        *actualRange = aRange;
    }
    NSWindow* window = [self window];
    NSRect contentRect = [window contentRectForFrameRect:[window frame]];
    NSRect rect = NSMakeRect(m_x, contentRect.size.height - m_y, 0, 0);
    return [window convertRectToScreen:rect];
}

- (NSAttributedString *)attributedSubstringForProposedRange:(NSRange)aRange actualRange:(NSRangePointer)actualRange {
    return nil;
}

- (NSInteger)conversationIdentifier {
    return (NSInteger) self;
}

- (NSUInteger)characterIndexForPoint:(NSPoint)thePoint {
    return 0;
}

- (NSArray *)validAttributesForMarkedText {
    return [NSArray array];
}

- (void)interpretKeyEvents:(NSArray<NSEvent *> *)eventArray {
    [super interpretKeyEvents: eventArray];
}

@end


static void ImeSetInputScreenPosFn_DefaultImpl(ImGuiViewport* viewport, ImVec2 pos) {
    if (IMEView* view = (IMEView*)viewport->PlatformHandle) {
        [view setPosX:(pos.x - viewport->Pos.x) setPosY:(pos.y - viewport->Pos.y)];
    }
}

void init_ime(void* window) {
    NSWindow* nswindow = (NSWindow*)window;
    IMEView* ime = [[IMEView alloc] initWithFrame: NSMakeRect(0.0, 0.0, 0.0, 0.0)];
    [nswindow setContentView: ime];
    [nswindow makeFirstResponder: ime];

    ImGuiViewport* viewport = ImGui::GetMainViewport();
    viewport->PlatformHandle = window;

    ImGuiPlatformIO& io = ImGui::GetPlatformIO();
    io.Platform_SetImeInputPos = ImeSetInputScreenPosFn_DefaultImpl;
}
