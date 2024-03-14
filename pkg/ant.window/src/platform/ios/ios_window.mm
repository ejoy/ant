#include "../../window.h"
#include "luabind.h"

#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#include <Foundation/Foundation.h>

#include <functional>
#include <mutex>
#include <vector>
#include <bee/thread/spinlock.h>
#include <lua.hpp>

extern "C" {
#include <3rd/lua-seri/lua-seri.h>
}

static int writelog(const char* msg) {
    NSArray* array = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if ([array count] <= 0) {
        return 1;
    }
    char path[256];
    const char* dir = [[array objectAtIndex:0] fileSystemRepresentation];
    snprintf(path, 256, "%s/game.log", dir);
    FILE* f = fopen(path, "a+");
    if (!f) {
        return 1;
    }
    fputs(msg, f);
    fclose(f);
    return 0;
}

@interface View : UIView
    @property (nonatomic, retain) CADisplayLink* m_displayLink;
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
    @property (nonatomic, retain) UIWindow* m_window;
    @property (nonatomic, retain) View*     m_view;
@end

id init_gesture();

View* global_window = NULL;
static id<MTLDevice> g_device = NULL;
static struct ant_window_callback s_cb;
struct ant_window_callback* g_cb = &s_cb;
id g_gesture;

static void push_touch_message(ant::window::touch_state state, UIView* view, NSSet* touches) {
    struct ant::window::msg_touch msg;
    msg.state = state;
    for (UITouch *touch in touches) {
        CGPoint pt = [touch locationInView:view];
        pt.x *= view.contentScaleFactor;
        pt.y *= view.contentScaleFactor;
        msg.id = (uintptr_t)touch;
        msg.x = pt.x;
        msg.y = pt.y;
        ant::window::input_message(g_cb->messageL, msg);
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
    if (w < h) {
        int tmp = w;
        w = h;
        h = tmp;
    }
    window_message_init(g_cb->messageL, (__bridge void*)self.layer, (__bridge void*)self.layer, (__bridge void*)g_device, w, h);

    g_gesture = init_gesture();
    return self;
}
- (void)layoutSubviews {
    uint32_t frameW = (uint32_t)(self.contentScaleFactor * self.frame.size.width);
    uint32_t frameH = (uint32_t)(self.contentScaleFactor * self.frame.size.height);
    window_message_size(g_cb->messageL, frameW, frameH);
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
    push_touch_message(ant::window::touch_state::began, self, [event allTouches]);
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    push_touch_message(ant::window::touch_state::moved, self,  [event allTouches]);
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    push_touch_message(ant::window::touch_state::ended, self,  [event allTouches]);
}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    push_touch_message(ant::window::touch_state::cancelled, self,  [event allTouches]);
}
- (void)maxfps:(float)fps {
    self.m_displayLink.preferredFrameRateRange = CAFrameRateRangeMake(fps, fps, fps);
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
    writelog("\n***applicationWillTerminate***\n");
    window_message_exit(g_cb->messageL);
    g_cb->update(g_cb);
    [self.m_view stop];
}
- (void)applicationWillResignActive:(UIApplication *)application {
    struct ant::window::msg_suspend msg;
    msg.what = ant::window::suspend::will_suspend;
    ant::window::input_message(g_cb->messageL, msg);
    g_cb->update(g_cb);
    [self.m_view stop];
}
- (void)applicationDidEnterBackground:(UIApplication *)application {
    struct ant::window::msg_suspend msg;
    msg.what = ant::window::suspend::did_suspend;
    ant::window::input_message(g_cb->messageL, msg);
    g_cb->update(g_cb);
}
- (void)applicationWillEnterForeground:(UIApplication *)application {
    struct ant::window::msg_suspend msg;
    msg.what = ant::window::suspend::will_resume;
    ant::window::input_message(g_cb->messageL, msg);
    g_cb->update(g_cb);
}
- (void)applicationDidBecomeActive:(UIApplication *)application {
    [self.m_view start];
    struct ant::window::msg_suspend msg;
    msg.what = ant::window::suspend::did_resume;
    ant::window::input_message(g_cb->messageL, msg);
    g_cb->update(g_cb);
}
- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return UIInterfaceOrientationMaskLandscape;
}
@end

typedef void(^SelectHandler)(void* data);

class MessageQueue {
public:
    void push(void* data) {
        std::unique_lock<bee::spinlock> lk(mutex);
        queue.push_back(data);
    }
    void select(std::function<void(void*)> handler) {
        std::unique_lock<bee::spinlock> lk(mutex);
        if (queue.empty()) {
            return;
        }
        for (void* data: queue) {
            handler(data);
        }
        queue.clear();
    }
private:
    std::vector<void*> queue;
    bee::spinlock mutex;
};

static MessageQueue g_msqueue;

static void MessageFetch(lua_State* L) {
    g_msqueue.push(seri_pack(L, 0, NULL));
    lua_settop(L, 0);
}

void loopwindow_init(struct ant_window_callback* cb) {
    g_cb->update = cb->update;
    g_cb->messageL = cb->messageL;
    g_cb->updateL = cb->updateL;
    window_message_set_fetch_func(MessageFetch);
}

void loopwindow_mainloop() {
    int argc = 0;
    char **argv = 0;
    UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
}

static bool peekmessage() {
    lua_State* L = g_cb->peekL;
    lua_Integer len = luaL_len(L, 1);
    g_msqueue.select([&](void* data){
        int n = seri_unpackptr(L, data);
        if (n > 0) {
            lua_settop(L, 2);
            lua_seti(L, 1, ++len);
        }
    });
    return len > 0;
}

bool window_init(lua_State* L, const char *size) {
    g_cb->peekL = L;
    while (true) {
        if (peekmessage()) {
            break;
        }
        sleep(1);
    }
    return true;
}

void window_close() {
}

bool window_peek_message() {
    peekmessage();
    return true;
}

void window_set_cursor(int cursor) {
}

void window_set_title(bee::zstring_view title) {
}

void window_set_maxfps(float fps) {
    //TODO
    //if (global_window) {
    //    [global_window maxfps: fps];
    //}
}
