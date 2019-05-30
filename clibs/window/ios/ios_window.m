#include "../window_native.h"
#include "ios_window.h"

@interface ViewController : UIViewController
@end
@implementation ViewController
- (BOOL)prefersStatusBarHidden {
    return YES;
}
@end

static id<MTLDevice> g_device = NULL;
static struct ant_window_callback* g_cb = NULL;

static void push_message(struct ant_window_message* msg) {
    if (g_cb) {
        g_cb->message(g_cb->ud, msg);
    }
}

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

    int w = (int)(self.contentScaleFactor * self.frame.size.width);
    int h = (int)(self.contentScaleFactor * self.frame.size.height);
    struct ant_window_message msg;
    msg.type = ANT_WINDOW_INIT;
    msg.u.init.window = (void*)self.layer;
    msg.u.init.context = (void*)g_device;
    msg.u.init.w = w;
    msg.u.init.h = h;
    push_message(&msg);
    return self;
}
- (void)layoutSubviews {
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
    struct ant_window_message msg;
    msg.type = ANT_WINDOW_UPDATE;
    push_message(&msg);
}
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint pt = [touch locationInView:self];
    pt.x *= self.contentScaleFactor;
    pt.y *= self.contentScaleFactor;
    struct ant_window_message msg;
    msg.type = ANT_WINDOW_MOUSE_CLICK;
    msg.u.mouse_click.type = 0;
    msg.u.mouse_click.press = 1;
    msg.u.mouse_click.x = pt.x;
    msg.u.mouse_click.y = pt.y;
    push_message(&msg);
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint pt = [touch locationInView:self];
    pt.x *= self.contentScaleFactor;
    pt.y *= self.contentScaleFactor;
    struct ant_window_message msg;
    msg.type = ANT_WINDOW_MOUSE_CLICK;
    msg.u.mouse_click.type = 0;
    msg.u.mouse_click.press = 0;
    msg.u.mouse_click.x = pt.x;
    msg.u.mouse_click.y = pt.y;
    push_message(&msg);
}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint pt = [touch locationInView:self];
    pt.x *= self.contentScaleFactor;
    pt.y *= self.contentScaleFactor;
    struct ant_window_message msg;
    msg.type = ANT_WINDOW_MOUSE_CLICK;
    msg.u.mouse_click.type = 0;
    msg.u.mouse_click.press = 0;
    msg.u.mouse_click.x = pt.x;
    msg.u.mouse_click.y = pt.y;
    push_message(&msg);
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint pt = [touch locationInView:self];
    pt.x *= self.contentScaleFactor;
    pt.y *= self.contentScaleFactor;
    struct ant_window_message msg;
    msg.type = ANT_WINDOW_MOUSE_MOVE;
    msg.u.mouse_move.state = 1;
    msg.u.mouse_move.x = pt.x;
    msg.u.mouse_move.y = pt.y;
    push_message(&msg);
}
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    CGRect rect = [[UIScreen mainScreen] bounds];
    float scale = [[UIScreen mainScreen] scale];
    self.m_window = [[UIWindow alloc] initWithFrame: rect];
    self.m_view = [[View alloc] initWithRect: rect WithScale: scale];
    [self.m_window addSubview: self.m_view];

    ViewController* mvc = [[ViewController alloc] init];
    mvc.view = self.m_view;
    [self.m_window setRootViewController: mvc];
    [self.m_window makeKeyAndVisible];

    return YES;
}
- (void)applicationDidBecomeActive:(UIApplication *)application {
    [self.m_view start];
}
- (void)applicationWillResignActive:(UIApplication *)application {
    [self.m_view stop];
}
- (void)applicationWillTerminate:(UIApplication *)application {
    struct ant_window_message msg;
    msg.type = ANT_WINDOW_EXIT;
    push_message(&msg);
    [self.m_view stop];
}
@end

int window_init(struct ant_window_callback* cb) {
    g_cb = cb;
    return 0;
}

int window_create(struct ant_window_callback* cb, int w, int h, const char* title, size_t sz) {
    // do nothing
    return 0;
}

void window_mainloop(struct ant_window_callback* cb) {
    // do nothing
}

void window_ime(void* ime) {
    // do nothing
}
