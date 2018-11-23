#include <Cocoa/Cocoa.h>
#include "wnd_osx.h"

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    bool terminated;
}
- (id)init;
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)aNotification;
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
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)aNotification {
    printf("applicationShouldTerminateAfterLastWindowClosed\n");
    return YES;
}
@end

id window_create(int w, int h, const char* title, size_t sz) {
    (void)sz;
    NSRect rc = NSMakeRect(0, 0, w, h);
	NSUInteger uiStyle = 0
		| NSWindowStyleMaskTitled
		| NSWindowStyleMaskResizable
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
    [nsTitle release];
    return win; 
}

void  window_mainloop() {
    [NSApp run];
}
