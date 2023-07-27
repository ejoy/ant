#include "../../window.h"
extern "C" {
#include <lua-seri.h>
}

#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

@interface View : UIView
    @property (nonatomic, retain) CADisplayLink* m_displayLink;
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
    @property (nonatomic, retain) UIWindow* m_window;
    @property (nonatomic, retain) View*     m_view;
@end

id init_gesture();

UIView* global_window = NULL;
static id<MTLDevice> g_device = NULL;
struct ant_window_callback* g_cb = NULL;
id g_gesture;

static void push_touch_message(ant::window::TOUCH_TYPE type, UIView* view, NSSet* touches) {
    struct ant::window::msg_touch msg;
    msg.type = type;
    for (UITouch *touch in touches) {
        CGPoint pt = [touch locationInView:view];
        pt.x *= view.contentScaleFactor;
        pt.y *= view.contentScaleFactor;
        msg.id = (uintptr_t)touch;
        msg.x = pt.x;
        msg.y = pt.y;
        ant::window::input_message(g_cb, msg);
    }
}

@interface ViewController : UIViewController
@end
@implementation ViewController
- (BOOL)prefersStatusBarHidden {
    return YES;
}
@end

@implementation View
+ (Class)layerClass  {
    Class metalClass = NSClassFromString(@"CAMetalLayer");
    if (metalClass != nil)  {
        g_device = MTLCreateSystemDefaultDevice();
        if (g_device) {
            return metalClass;
       }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [CAEAGLLayer class];
#pragma clang diagnostic pop
}
- (id)initWithRect:(CGRect)rect WithScale: (float)scale {
    self = [super initWithFrame:rect];
    if (nil == self) {
        return nil;
    }
    [self setContentScaleFactor: scale];

    global_window = self;

    int w = (int)(self.contentScaleFactor * self.frame.size.width);
    int h = (int)(self.contentScaleFactor * self.frame.size.height);
    window_message_init(g_cb, (__bridge void*)self.layer, (__bridge void*)g_device, w, h);

    g_gesture = init_gesture();
    return self;
}
- (void)layoutSubviews {
    uint32_t frameW = (uint32_t)(self.contentScaleFactor * self.frame.size.width);
    uint32_t frameH = (uint32_t)(self.contentScaleFactor * self.frame.size.height);
    window_message_size(g_cb, frameW, frameH, 0);
}
- (void)start {
    if (nil == self.m_displayLink) {
        self.m_displayLink = [self.window.screen displayLinkWithTarget:self selector:@selector(renderFrame)];
        [self.m_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    }
}
- (void)stop {
    if (nil != self.m_displayLink) {
        [self.m_displayLink invalidate];
        self.m_displayLink = nil;
    }
}
- (void)renderFrame {
    g_cb->update(g_cb);
}
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    push_touch_message(ant::window::TOUCH_BEGAN, self, [event allTouches]);
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    push_touch_message(ant::window::TOUCH_MOVED, self,  [event allTouches]);
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    push_touch_message(ant::window::TOUCH_ENDED, self,  [event allTouches]);
}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    push_touch_message(ant::window::TOUCH_CANCELLED, self,  [event allTouches]);
}
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    application.idleTimerDisabled = true;

    CGRect rect = [[UIScreen mainScreen] bounds];
    float scale = [[UIScreen mainScreen] scale];
    self.m_window = [[UIWindow alloc] initWithFrame: rect];
    
    [self.m_window setBackgroundColor:[UIColor whiteColor]];
    
    self.m_view = [[View alloc] initWithRect: rect WithScale: scale];
    self.m_view.multipleTouchEnabled = false;
    //[self.m_window addSubview: self.m_view];

    ViewController* mvc = [[ViewController alloc] init];
    mvc.view = self.m_view;
    [self.m_window setRootViewController: mvc];
    [self.m_window makeKeyAndVisible];
    [self.m_view start];
    return YES;
}
- (void) applicationWillTerminate:(UIApplication *)application {
    window_message_exit(g_cb);
    [self.m_view stop];
}
- (void)applicationWillResignActive:(UIApplication *)application {
    struct ant::window::msg_suspend msg;
    msg.what = ant::window::suspend::will_suspend;
    ant::window::input_message(g_cb, msg);
    g_cb->update(g_cb);
    [self.m_view stop];
}
- (void)applicationDidEnterBackground:(UIApplication *)application {
    struct ant::window::msg_suspend msg;
    msg.what = ant::window::suspend::did_suspend;
    ant::window::input_message(g_cb, msg);
    g_cb->update(g_cb);
}
- (void)applicationWillEnterForeground:(UIApplication *)application {
    struct ant::window::msg_suspend msg;
    msg.what = ant::window::suspend::will_resume;
    ant::window::input_message(g_cb, msg);
    g_cb->update(g_cb);
}
- (void)applicationDidBecomeActive:(UIApplication *)application {
    [self.m_view start];
    struct ant::window::msg_suspend msg;
    msg.what = ant::window::suspend::did_resume;
    ant::window::input_message(g_cb, msg);
    g_cb->update(g_cb);
}
- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return UIInterfaceOrientationMaskLandscape;
}
@end

int window_init(struct ant_window_callback* cb) {
    g_cb = cb;
    return 0;
}

void window_mainloop() {
    int argc = 0;
    char **argv = 0;
    UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
}
