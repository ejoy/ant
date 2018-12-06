#include "../window_native.h"
#include "ios_window.h"

@interface ViewController : UIViewController
@end
@implementation ViewController
- (BOOL)prefersStatusBarHidden {
    return YES;
}
@end

static CALayer* g_layer = NULL;
static id<MTLDevice> g_device = NULL;
static struct ant_window_callback* g_cb = NULL;

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
- (id)initWithFrame:(CGRect)rect {
    self = [super initWithFrame:rect];
    if (nil == self) {
        return nil;
    }
    g_layer = self.layer;
    self.backgroundColor = [UIColor yellowColor];
    return self;
}
- (void)layoutSubviews {
    int w = (int)(self.contentScaleFactor * self.frame.size.width);
    int h = (int)(self.contentScaleFactor * self.frame.size.height);

    struct ant_window_message msg;
    msg.type = ANT_WINDOW_INIT;
    msg.u.init.window = (void*)g_layer;
    msg.u.init.context = (void*)g_device;
    msg.u.init.w = w;
    msg.u.init.h = h;
    g_cb->message(g_cb->ud, &msg);
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
    if (!g_cb) return;
    struct ant_window_message update_msg;
    update_msg.type = ANT_WINDOW_UPDATE;
    g_cb->message(g_cb->ud, &update_msg);
}
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
}
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    CGRect rect = [[UIScreen mainScreen] bounds];
    self.m_window = [[UIWindow alloc] initWithFrame: rect];
    self.m_view = [ [View alloc] initWithFrame: rect];
    [self.m_window addSubview: self.m_view];
    
    ViewController* mvc = [[ViewController alloc] init];
    mvc.view = self.m_view;
    [self.m_window setRootViewController: mvc];
    [self.m_window makeKeyAndVisible];
    
    float scaleFactor = [[UIScreen mainScreen] scale];
    [self.m_view setContentScaleFactor: scaleFactor ];
    return YES;
}
- (void)applicationDidBecomeActive:(UIApplication *)application {
    [self.m_view start];
}
- (void)applicationWillResignActive:(UIApplication *)application {
    [self.m_view stop];
}
- (void)applicationWillTerminate:(UIApplication *)application {
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
