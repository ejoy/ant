#include <Cocoa/Cocoa.h>
#include "../window_native.h"

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
    struct ant_window_callback* m_cb;
}
- (id)init;
- (void)initAntCallback:(struct ant_window_callback*)callback;
- (void)getMouseX:(int32_t*)outx getMouseY:(int32_t*)outy;
- (void)windowCreated:(NSWindow*)window;
- (void)windowWillClose:(NSNotification*)notification;
- (BOOL)windowShouldClose:(NSWindow*)window;
- (void)windowDidResize:(NSNotification*)notification;
- (void)windowDidBecomeKey:(NSNotification *)notification;
- (void)windowDidResignKey:(NSNotification *)notification;
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
- (void)initAntCallback:(struct ant_window_callback*)callback {
    m_cb = callback;
}
- (void)getMouseX:(int32_t*)outx getMouseY:(int32_t*)outy {
	NSRect  originalFrame = [m_window frame];
	NSPoint location      = [m_window mouseLocationOutsideOfEventStream];
	NSRect  adjustFrame   = [m_window contentRectForFrameRect: originalFrame];
	int32_t x = location.x;
	int32_t y = (int32_t)adjustFrame.size.height - (int32_t)location.y;
	*outx = clamp(x, 0, (int32_t)adjustFrame.size.width);
	*outy = clamp(y, 0, (int32_t)adjustFrame.size.height);
}
- (void)windowCreated:(NSWindow*)window {
	assert(window);
	[window setDelegate:self];
	assert(self->m_count < ~0u);
	self->m_count += 1;
}
- (void)windowWillClose:(NSNotification*)notification {
	(void)notification;
	struct ant_window_message msg;
    msg.type = ANT_WINDOW_EXIT;
	m_cb->message(m_cb->ud, &msg);
}
- (BOOL)windowShouldClose:(NSWindow*)window {
	assert(window);
	[window setDelegate:nil];
	assert(self->m_count);
	self->m_count -= 1;
	if (self->m_count == 0) {
		[NSApp terminate:self];
		return false;
	}
	return true;
}
- (void)windowDidResize:(NSNotification*)notification {
	(void)notification;
}
- (void)windowDidBecomeKey:(NSNotification*)notification {
	(void)notification;
}
- (void)windowDidResignKey:(NSNotification*)notification {
	(void)notification;
}
@end

WindowDelegate* g_wd;
int32_t g_mx;
int32_t g_my;

void* window_create(int w, int h, const char* title, size_t sz) {
    (void)sz;
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
    NSString* nsTitle = [[NSString alloc] initWithUTF8String:title];
    [win setTitle:nsTitle];
    [win center];
    [win makeKeyAndOrderFront:win];
    [win makeMainWindow];
    g_wd = [WindowDelegate new];
	[g_wd windowCreated:win];
    [nsTitle release];
    return win; 
}

static NSEvent* peek_event() {
	return [NSApp
		nextEventMatchingMask:NSEventMaskAny
		untilDate:[NSDate distantPast] // do not wait for event
		inMode:NSDefaultRunLoopMode
		dequeue:YES
	];
}

static uint8_t get_keystate(NSEvent* event) {
    int flags = [event modifierFlags];
	return 0
		| (0 != (flags & NSEventModifierFlagShift  ))  ? (uint8_t)(1 << KB_SHIFT)    : 0
		| (0 != (flags & NSEventModifierFlagOption ))  ? (uint8_t)(1 << KB_ALT)      : 0
		| (0 != (flags & NSEventModifierFlagControl))  ? (uint8_t)(1 << KB_CTRL)     : 0
		| (0 != (flags & NSEventModifierFlagCommand))  ? (uint8_t)(1 << KB_SYS)      : 0
		| (0 != (flags & NSEventModifierFlagCapsLock)) ? (uint8_t)(1 << KB_CAPSLOCK) : 0
		;
}

static bool dispatch_event(struct ant_window_callback* cb, NSEvent* event) {
	if (!event) {
	    return false;
	}
	NSEventType eventType = [event type];
	struct ant_window_message msg;

	switch (eventType) {
	case NSEventTypeMouseMoved:
	case NSEventTypeLeftMouseDragged:
	case NSEventTypeRightMouseDragged:
	case NSEventTypeOtherMouseDragged:
		[g_wd getMouseX:&g_mx getMouseY:&g_my];
		msg.type = ANT_WINDOW_MOVE;
        msg.u.mouse.x = g_mx;
        msg.u.mouse.y = g_my;
		cb->message(cb->ud, &msg);
        break;
	case NSEventTypeLeftMouseDown:
	case NSEventTypeLeftMouseUp:
	    // Command + Left Mouse Button acts as middle! This just a temporary solution!
		// This is because the average OSX user doesn't have middle mouse click.
		msg.type = ANT_WINDOW_MOUSE;
		msg.u.mouse.type = ([event modifierFlags] & NSEventModifierFlagCommand) ? 2 : 0;
		msg.u.mouse.press = (eventType == NSEventTypeLeftMouseDown) ? 1 : 0;
        msg.u.mouse.x = g_mx;
        msg.u.mouse.y = g_my;
		cb->message(cb->ud, &msg);
        break;
	case NSEventTypeRightMouseDown:
	case NSEventTypeRightMouseUp:
		msg.type = ANT_WINDOW_MOUSE;
		msg.u.mouse.type = 1;
		msg.u.mouse.press = (eventType == NSEventTypeRightMouseDown) ? 1 : 0;
        msg.u.mouse.x = g_mx;
        msg.u.mouse.y = g_my;
		cb->message(cb->ud, &msg);
        break;
	case NSEventTypeOtherMouseDown:
	case NSEventTypeOtherMouseUp:
		msg.type = ANT_WINDOW_MOUSE;
		msg.u.mouse.type = 2;
		msg.u.mouse.press = (eventType == NSEventTypeOtherMouseDown) ? 1 : 0;
        msg.u.mouse.x = g_mx;
        msg.u.mouse.y = g_my;
		cb->message(cb->ud, &msg);
        break;
	case NSEventTypeScrollWheel:
        break;
	case NSEventTypeKeyDown:
		msg.type = ANT_WINDOW_KEYBOARD;
		msg.u.keyboard.state = get_keystate(event);
		msg.u.keyboard.press = 1;
		//msg.u.keyboard.key = (int)wParam;
		cb->message(cb->ud, &msg);
		break;
	case NSEventTypeKeyUp:
		msg.type = ANT_WINDOW_KEYBOARD;
		msg.u.keyboard.state = get_keystate(event);
		msg.u.keyboard.press = 0;
		//msg.u.keyboard.key = (int)wParam;
		cb->message(cb->ud, &msg);
		break;
	default:
		break;
    }
	[NSApp sendEvent:event];
	[NSApp updateWindows];
	return true;
}

void window_mainloop(struct ant_window_callback* cb) {
    if (!g_wd) {
        return;
    }
    [g_wd initAntCallback: cb];
	struct ant_window_message update_msg;
	update_msg.type = ANT_WINDOW_UPDATE;
	@autoreleasepool {
        [NSApplication sharedApplication];
        id dg = [AppDelegate new];
        [NSApp setDelegate:dg];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp activateIgnoringOtherApps:YES];
        [NSApp finishLaunching];
        while (![dg applicationHasTerminated]) {
			cb->message(cb->ud, &update_msg);
            while (dispatch_event(cb, peek_event())) { }
        }
    }
}
