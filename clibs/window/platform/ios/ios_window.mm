#include "../../window.h"
#include "ios_window.h"
#include "window.h"
extern "C" {
#include <lua-seri.h>
}

id init_gesture();

UIView* global_window = NULL;
static id<MTLDevice> g_device = NULL;
struct ant_window_callback* g_cb = NULL;
id g_gesture;

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
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    application.idleTimerDisabled = true;

    CGRect rect = [[UIScreen mainScreen] bounds];
    float scale = [[UIScreen mainScreen] scale];
    self.m_window = [[UIWindow alloc] initWithFrame: rect];
    
    [self.m_window setBackgroundColor:[UIColor whiteColor]];
    
    self.m_view = [[View alloc] initWithRect: rect WithScale: scale];
    self.m_view.multipleTouchEnabled = true;
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
