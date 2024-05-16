#include <Cocoa/Cocoa.h>
#include "../../window.h"
#include <Carbon/Carbon.h>
#import <QuartzCore/CAMetalLayer.h>
#include <stdio.h>

static ant::window::keyboard_state get_keyboard_state(NSEvent* event) {
    int flags = [event modifierFlags];
    return ant::window::get_keystate(
        0 != (flags & NSEventModifierFlagShift  ),
        0 != (flags & NSEventModifierFlagOption ),
        0 != (flags & NSEventModifierFlagControl),
        0 != (flags & NSEventModifierFlagCommand),
        0 != (flags & NSEventModifierFlagCapsLock)
    );
}

static ImGuiKey ToImGuiKey(int key_code) {
    switch (key_code) {
        case kVK_ANSI_A: return ImGuiKey_A;
        case kVK_ANSI_S: return ImGuiKey_S;
        case kVK_ANSI_D: return ImGuiKey_D;
        case kVK_ANSI_F: return ImGuiKey_F;
        case kVK_ANSI_H: return ImGuiKey_H;
        case kVK_ANSI_G: return ImGuiKey_G;
        case kVK_ANSI_Z: return ImGuiKey_Z;
        case kVK_ANSI_X: return ImGuiKey_X;
        case kVK_ANSI_C: return ImGuiKey_C;
        case kVK_ANSI_V: return ImGuiKey_V;
        case kVK_ANSI_B: return ImGuiKey_B;
        case kVK_ANSI_Q: return ImGuiKey_Q;
        case kVK_ANSI_W: return ImGuiKey_W;
        case kVK_ANSI_E: return ImGuiKey_E;
        case kVK_ANSI_R: return ImGuiKey_R;
        case kVK_ANSI_Y: return ImGuiKey_Y;
        case kVK_ANSI_T: return ImGuiKey_T;
        case kVK_ANSI_1: return ImGuiKey_1;
        case kVK_ANSI_2: return ImGuiKey_2;
        case kVK_ANSI_3: return ImGuiKey_3;
        case kVK_ANSI_4: return ImGuiKey_4;
        case kVK_ANSI_6: return ImGuiKey_6;
        case kVK_ANSI_5: return ImGuiKey_5;
        case kVK_ANSI_Equal: return ImGuiKey_Equal;
        case kVK_ANSI_9: return ImGuiKey_9;
        case kVK_ANSI_7: return ImGuiKey_7;
        case kVK_ANSI_Minus: return ImGuiKey_Minus;
        case kVK_ANSI_8: return ImGuiKey_8;
        case kVK_ANSI_0: return ImGuiKey_0;
        case kVK_ANSI_RightBracket: return ImGuiKey_RightBracket;
        case kVK_ANSI_O: return ImGuiKey_O;
        case kVK_ANSI_U: return ImGuiKey_U;
        case kVK_ANSI_LeftBracket: return ImGuiKey_LeftBracket;
        case kVK_ANSI_I: return ImGuiKey_I;
        case kVK_ANSI_P: return ImGuiKey_P;
        case kVK_ANSI_L: return ImGuiKey_L;
        case kVK_ANSI_J: return ImGuiKey_J;
        case kVK_ANSI_Quote: return ImGuiKey_Apostrophe;
        case kVK_ANSI_K: return ImGuiKey_K;
        case kVK_ANSI_Semicolon: return ImGuiKey_Semicolon;
        case kVK_ANSI_Backslash: return ImGuiKey_Backslash;
        case kVK_ANSI_Comma: return ImGuiKey_Comma;
        case kVK_ANSI_Slash: return ImGuiKey_Slash;
        case kVK_ANSI_N: return ImGuiKey_N;
        case kVK_ANSI_M: return ImGuiKey_M;
        case kVK_ANSI_Period: return ImGuiKey_Period;
        case kVK_ANSI_Grave: return ImGuiKey_GraveAccent;
        case kVK_ANSI_KeypadDecimal: return ImGuiKey_KeypadDecimal;
        case kVK_ANSI_KeypadMultiply: return ImGuiKey_KeypadMultiply;
        case kVK_ANSI_KeypadPlus: return ImGuiKey_KeypadAdd;
        case kVK_ANSI_KeypadClear: return ImGuiKey_NumLock;
        case kVK_ANSI_KeypadDivide: return ImGuiKey_KeypadDivide;
        case kVK_ANSI_KeypadEnter: return ImGuiKey_KeypadEnter;
        case kVK_ANSI_KeypadMinus: return ImGuiKey_KeypadSubtract;
        case kVK_ANSI_KeypadEquals: return ImGuiKey_KeypadEqual;
        case kVK_ANSI_Keypad0: return ImGuiKey_Keypad0;
        case kVK_ANSI_Keypad1: return ImGuiKey_Keypad1;
        case kVK_ANSI_Keypad2: return ImGuiKey_Keypad2;
        case kVK_ANSI_Keypad3: return ImGuiKey_Keypad3;
        case kVK_ANSI_Keypad4: return ImGuiKey_Keypad4;
        case kVK_ANSI_Keypad5: return ImGuiKey_Keypad5;
        case kVK_ANSI_Keypad6: return ImGuiKey_Keypad6;
        case kVK_ANSI_Keypad7: return ImGuiKey_Keypad7;
        case kVK_ANSI_Keypad8: return ImGuiKey_Keypad8;
        case kVK_ANSI_Keypad9: return ImGuiKey_Keypad9;
        case kVK_Return: return ImGuiKey_Enter;
        case kVK_Tab: return ImGuiKey_Tab;
        case kVK_Space: return ImGuiKey_Space;
        case kVK_Delete: return ImGuiKey_Backspace;
        case kVK_Escape: return ImGuiKey_Escape;
        case kVK_CapsLock: return ImGuiKey_CapsLock;
        case kVK_Control: return ImGuiKey_LeftCtrl;
        case kVK_Shift: return ImGuiKey_LeftShift;
        case kVK_Option: return ImGuiKey_LeftAlt;
        case kVK_Command: return ImGuiKey_LeftSuper;
        case kVK_RightControl: return ImGuiKey_RightCtrl;
        case kVK_RightShift: return ImGuiKey_RightShift;
        case kVK_RightOption: return ImGuiKey_RightAlt;
        case kVK_RightCommand: return ImGuiKey_RightSuper;
//      case kVK_Function: return ImGuiKey_;
//      case kVK_VolumeUp: return ImGuiKey_;
//      case kVK_VolumeDown: return ImGuiKey_;
//      case kVK_Mute: return ImGuiKey_;
        case kVK_F1: return ImGuiKey_F1;
        case kVK_F2: return ImGuiKey_F2;
        case kVK_F3: return ImGuiKey_F3;
        case kVK_F4: return ImGuiKey_F4;
        case kVK_F5: return ImGuiKey_F5;
        case kVK_F6: return ImGuiKey_F6;
        case kVK_F7: return ImGuiKey_F7;
        case kVK_F8: return ImGuiKey_F8;
        case kVK_F9: return ImGuiKey_F9;
        case kVK_F10: return ImGuiKey_F10;
        case kVK_F11: return ImGuiKey_F11;
        case kVK_F12: return ImGuiKey_F12;
        case kVK_F13: return ImGuiKey_F13;
        case kVK_F14: return ImGuiKey_F14;
        case kVK_F15: return ImGuiKey_F15;
        case kVK_F16: return ImGuiKey_F16;
        case kVK_F17: return ImGuiKey_F17;
        case kVK_F18: return ImGuiKey_F18;
        case kVK_F19: return ImGuiKey_F19;
        case kVK_F20: return ImGuiKey_F20;
        case 0x6E: return ImGuiKey_Menu;
        case kVK_Help: return ImGuiKey_Insert;
        case kVK_Home: return ImGuiKey_Home;
        case kVK_PageUp: return ImGuiKey_PageUp;
        case kVK_ForwardDelete: return ImGuiKey_Delete;
        case kVK_End: return ImGuiKey_End;
        case kVK_PageDown: return ImGuiKey_PageDown;
        case kVK_LeftArrow: return ImGuiKey_LeftArrow;
        case kVK_RightArrow: return ImGuiKey_RightArrow;
        case kVK_DownArrow: return ImGuiKey_DownArrow;
        case kVK_UpArrow: return ImGuiKey_UpArrow;
        default: return ImGuiKey_None;
    }
}

static int32_t clamp(int32_t v, int32_t min, int32_t max) {
    if (v < min) {
        return min;
    }
    if (v > max) {
        return max;
    }
    return v;
}

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    bool terminated;
}
- (id)init;
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender;
- (bool)applicationHasTerminated;
@end

@implementation AppDelegate
- (id)init {
    self = [super init];
    if (nil == self) {
        return nil;
    }
    self->terminated = false;
    return self;
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	(void)sender;
	self->terminated = true;
	return NSTerminateCancel;
}
- (bool)applicationHasTerminated {
	return self->terminated;
}
@end

@interface WindowDelegate : NSObject<NSWindowDelegate> {
    uint32_t m_count;
    NSWindow* m_window;
    lua_State* m_L;
}
- (id)init;
- (void)getMouseX:(int32_t*)outx getMouseY:(int32_t*)outy;
- (void)windowCreated:(NSWindow*)window lua:(lua_State*)L ;
- (void)windowWillClose:(NSNotification*)notification;
- (BOOL)windowShouldClose:(NSWindow*)window;
@end

@implementation WindowDelegate
- (id)init {
	self = [super init];
	if (nil == self) {
		return nil;
	}
	self->m_count = 0;
	return self;
}
- (void)getMouseX:(int32_t*)outx getMouseY:(int32_t*)outy {
	NSRect  originalFrame = [m_window frame];
	NSPoint location      = [m_window mouseLocationOutsideOfEventStream];
	NSRect  adjustFrame   = [m_window contentRectForFrameRect: originalFrame];
    float scale = [m_window backingScaleFactor];
	int32_t x = location.x;
	int32_t y = (int32_t)adjustFrame.size.height - (int32_t)location.y;
	*outx = scale * clamp(x, 0, (int32_t)adjustFrame.size.width);
	*outy = scale * clamp(y, 0, (int32_t)adjustFrame.size.height);
}
- (void)windowCreated:(NSWindow*)window lua:(lua_State*)L {
	assert(window);
    m_window = window;
    m_L = L;
	[window setDelegate:self];
	assert(self->m_count < ~0u);
	self->m_count += 1;
}
- (void)windowWillClose:(NSNotification*)notification {
	(void)notification;
    window_message_exit(m_L);
}
- (BOOL)windowShouldClose:(NSWindow*)window {
	assert(window);
	assert(self->m_count);
	self->m_count -= 1;
	if (self->m_count == 0) {
		[NSApp terminate:self];
	}
	return YES;
}
@end

id g_dg;
lua_State* g_L;
WindowDelegate* g_wd = nil;
int32_t g_mx = 0;
int32_t g_my = 0;

CALayer* getLayer(NSWindow* nsWindow) {
	NSView* contentView = [nsWindow contentView];
	[contentView setWantsLayer:YES];
    CALayer* metalLayer = [CAMetalLayer layer];
    [contentView setLayer:metalLayer];
	return metalLayer;
}

bool window_init(lua_State* L, const char *size) {
	NSScreen *screen = [NSScreen mainScreen];
	NSRect visibleFrame = screen.visibleFrame;
	int w = (int)(visibleFrame.size.width * 0.7f);
	int h = (int)(w / 16.f * 9.f);
	if (size) {
		int ww, hh;
		if (sscanf(size, "%dx%d", &ww, &hh) == 2) {
			w = ww;
			h = hh;
		}
	}
    NSRect rc = NSMakeRect(0, 0, w, h);
	NSUInteger uiStyle = 0
		| NSWindowStyleMaskTitled
		| NSWindowStyleMaskClosable
		| NSWindowStyleMaskMiniaturizable
		;
    NSWindow* win = [[NSWindow alloc]
        initWithContentRect:rc
        styleMask:uiStyle
        backing:NSBackingStoreBuffered defer:NO
    ];

    [win center];
    [win makeKeyAndOrderFront:win];
    [win makeMainWindow];

    g_wd = [WindowDelegate new];
    [g_wd windowCreated:win lua:L];

    [NSApplication sharedApplication];
    g_dg = [AppDelegate new];
    [NSApp setDelegate:g_dg];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp finishLaunching];
    g_L = L;

    float scale = [win backingScaleFactor];
    window_message_init(L, win, getLayer(win), NULL, NULL, w * scale, h * scale);
    return true;
}

static NSEvent* peek_event() {
	return [NSApp
		nextEventMatchingMask:NSEventMaskAny
		untilDate:[NSDate distantPast] // do not wait for event
		inMode:NSDefaultRunLoopMode
		dequeue:YES
	];
}

static bool dispatch_event(lua_State* L, NSEvent* event) {
	if (!event) {
	    return false;
	}
	NSEventType eventType = [event type];

    switch (eventType) {
    case NSEventTypeScrollWheel: {
        struct ant::window::msg_mousewheel msg;
        msg.delta = 0.5f * [event scrollingDeltaY];
        msg.x = g_mx;
        msg.y = g_my;
        ant::window::input_message(L, msg);
        break;
    }
    case NSEventTypeMouseMoved: {
        [g_wd getMouseX:&g_mx getMouseY:&g_my];
        break;
    }
    case NSEventTypeLeftMouseDragged:
    case NSEventTypeRightMouseDragged:
    case NSEventTypeOtherMouseDragged: {
        [g_wd getMouseX:&g_mx getMouseY:&g_my];
        struct ant::window::msg_mousemove msg;
        msg.x = g_mx;
        msg.y = g_my;
        switch (eventType) {
        case NSEventTypeLeftMouseDragged:  msg.what = ant::window::mouse_buttons::left; break;
        case NSEventTypeRightMouseDragged: msg.what = ant::window::mouse_buttons::right; break;
        case NSEventTypeOtherMouseDragged: msg.what = ant::window::mouse_buttons::middle; break;
        default: msg.what = ant::window::mouse_buttons::none; break;
        }
        ant::window::input_message(L, msg);
        break;
    }
    case NSEventTypeLeftMouseDown:
    case NSEventTypeRightMouseDown:
    case NSEventTypeOtherMouseDown: {
        struct ant::window::msg_mouseclick msg;
        msg.state = ant::window::mouse_state::down;
        msg.x = g_mx;
        msg.y = g_my;
        switch (eventType) {
        case NSEventTypeLeftMouseDown:  msg.what = ant::window::mouse_button::left; break;
        case NSEventTypeRightMouseDown: msg.what = ant::window::mouse_button::right; break;
        case NSEventTypeOtherMouseDown: msg.what = ant::window::mouse_button::middle; break;
        default: break;
        }
        ant::window::input_message(L, msg);
        break;
    }
    case NSEventTypeLeftMouseUp:
    case NSEventTypeRightMouseUp:
    case NSEventTypeOtherMouseUp: {
        struct ant::window::msg_mouseclick msg;
        msg.state = ant::window::mouse_state::up;
        msg.x = g_mx;
        msg.y = g_my;
        switch (eventType) {
        case NSEventTypeLeftMouseUp:  msg.what = ant::window::mouse_button::left; break;
        case NSEventTypeRightMouseUp: msg.what = ant::window::mouse_button::right; break;
        case NSEventTypeOtherMouseUp: msg.what = ant::window::mouse_button::middle; break;
        default: break;
        }
        ant::window::input_message(L, msg);
        break;
    }
    case NSEventTypeKeyDown:
    case NSEventTypeKeyUp: {
        struct ant::window::msg_keyboard msg;
        int key_code = (int)[event keyCode];
        msg.key = ToImGuiKey(key_code);
        msg.state = get_keyboard_state(event);
        msg.press = (eventType == NSEventTypeKeyDown) ? 1 : 0;
        ant::window::input_message(L, msg);
        break;
    }
    default:
        break;
    }
    [NSApp sendEvent:event];
    [NSApp updateWindows];
    return true;
}

void window_close() {
}

bool window_peek_message() {
    if ([g_dg applicationHasTerminated]) {
        return false;
    }
    @autoreleasepool {
        while (dispatch_event(g_L, peek_event())) { }
    }
    return true;
}

void ant::window::set_message(ant::window::set_msg& msg) {
}
