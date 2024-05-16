#include "../../window.h"

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

static View* global_window = NULL;
static id<MTLDevice> g_device = NULL;
static id g_gesture;
static struct lua_State* g_peekL = NULL;
static struct lua_State* g_callbackL = NULL;
static struct lua_State* g_messageL = NULL;

static void lua_callback(const char* what) {
	lua_State* L = g_callbackL;
	lua_pushvalue(L, 2);
	lua_pushstring(L, what);
	if (lua_pcall(L, 1, 0, 1) != LUA_OK) {
		printf("Error: %s\n", lua_tostring(L, -1));
		lua_pop(L, 1);
	}
}

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
        ant::window::input_message(g_peekL, msg);
    }
}

static  ant::window::gesture_state getState(UIGestureRecognizerState v) {
    switch (v) {
    case UIGestureRecognizerStateBegan:
        return ant::window::gesture_state::began;
    case UIGestureRecognizerStateChanged:
        return ant::window::gesture_state::changed;
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled:
        return ant::window::gesture_state::ended;
    case UIGestureRecognizerStatePossible:
    case UIGestureRecognizerStateFailed:
    default:
        return ant::window::gesture_state::unknown;
    }
}

static CGPoint getLocationInView(UIGestureRecognizer* gesture) {
    CGPoint pt = [gesture locationInView:global_window];
    pt.x *= global_window.contentScaleFactor;
    pt.y *= global_window.contentScaleFactor;
    return pt;
}

static CGPoint getLocationOfTouch(UIGestureRecognizer* gesture) {
    NSUInteger n = gesture.numberOfTouches;
    CGPoint sum;
    sum.x = 0;
    sum.y = 0;
    for (NSUInteger i = 0; i < n; ++i) {
        CGPoint pt = [gesture locationOfTouch:i inView:global_window];
        sum.x += pt.x;
        sum.y += pt.y;
    }
    sum.x *= global_window.contentScaleFactor / n;
    sum.y *= global_window.contentScaleFactor / n;
    return sum;
}

@interface LuaGestureHandler : NSObject {
}
@end
@implementation LuaGestureHandler
-(void)handleTap:(UITapGestureRecognizer *)gesture {
    auto pt = getLocationInView(gesture);
    struct ant::window::msg_gesture_tap msg;
    msg.x = pt.x;
    msg.y = pt.y;
    ant::window::input_message(g_peekL, msg);
}
-(void)handlePinch:(UIPinchGestureRecognizer *)gesture {
    auto state = getState(gesture.state);
    if (state == ant::window::gesture_state::unknown) {
        return;
    }
    auto pt = getLocationOfTouch(gesture);
    struct ant::window::msg_gesture_pinch msg;
    msg.state = state;
    msg.x = pt.x;
    msg.y = pt.y;
    msg.velocity = gesture.velocity;
    ant::window::input_message(g_peekL, msg);
}
-(void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    auto state = getState(gesture.state);
    if (state == ant::window::gesture_state::unknown) {
        return;
    }
    auto pt = getLocationInView(gesture);
    struct ant::window::msg_gesture_longpress msg;
    msg.state = state;
    msg.x = pt.x;
    msg.y = pt.y;
    ant::window::input_message(g_peekL, msg);
}
-(void)handlePan:(UIPanGestureRecognizer *)gesture {
    auto state = getState(gesture.state);
    if (state == ant::window::gesture_state::unknown) {
        return;
    }
    struct ant::window::msg_gesture_pan msg;
    auto pt = getLocationInView(gesture);
    CGPoint velocity = [gesture velocityInView:global_window];
    msg.state = state;
    msg.x = pt.x;
    msg.y = pt.y;
    velocity.x *= global_window.contentScaleFactor;
    velocity.y *= global_window.contentScaleFactor;
    msg.velocity_x = velocity.x;
    msg.velocity_y = velocity.y;
    ant::window::input_message(g_peekL, msg);
}
-(void)handleSwipe:(UISwipeGestureRecognizer *)gesture {
    auto state = getState(gesture.state);
    if (state == ant::window::gesture_state::unknown) {
        return;
    }
    struct ant::window::msg_gesture_swipe msg;
    auto pt = getLocationInView(gesture);
    msg.state = state;
    msg.x = pt.x;
    msg.y = pt.y;
    msg.direction = (ant::window::swipe_direction)gesture.direction;
    ant::window::input_message(g_peekL, msg);
}
@end

static id init_gesture() {
    LuaGestureHandler* handler = [[LuaGestureHandler alloc] init];
    UITapGestureRecognizer* tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:handler action:@selector(handleTap:)];
    UIPinchGestureRecognizer* pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:handler action:@selector(handlePinch:)];
    UILongPressGestureRecognizer* longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:handler action:@selector(handleLongPress:)];
    UIPanGestureRecognizer* panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:handler action:@selector(handlePan:)];
    [global_window addGestureRecognizer:tapGesture];
    [global_window addGestureRecognizer:pinchGesture];
    [global_window addGestureRecognizer:longPressGesture];
    [global_window addGestureRecognizer:panGesture];
    return handler;
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
    window_message_init(g_peekL, (__bridge void*)self.layer, (__bridge void*)self.layer, NULL, (__bridge void*)g_device, w, h);
    lua_callback("init");

    g_gesture = init_gesture();
    return self;
}
- (void)layoutSubviews {
    uint32_t frameW = (uint32_t)(self.contentScaleFactor * self.frame.size.width);
    uint32_t frameH = (uint32_t)(self.contentScaleFactor * self.frame.size.height);
    window_message_size(g_peekL, frameW, frameH);
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
    window_message_exit(g_peekL);
    lua_callback("exit");
    [self.m_view stop];
}
- (void)applicationWillResignActive:(UIApplication *)application {
    struct ant::window::msg_suspend msg;
    msg.what = ant::window::suspend::will_suspend;
    ant::window::input_message(g_peekL, msg);
    [self.m_view stop];
}
- (void)applicationDidEnterBackground:(UIApplication *)application {
    struct ant::window::msg_suspend msg;
    msg.what = ant::window::suspend::did_suspend;
    ant::window::input_message(g_peekL, msg);
}
- (void)applicationWillEnterForeground:(UIApplication *)application {
    struct ant::window::msg_suspend msg;
    msg.what = ant::window::suspend::will_resume;
    ant::window::input_message(g_peekL, msg);
}
- (void)applicationDidBecomeActive:(UIApplication *)application {
    [self.m_view start];
    struct ant::window::msg_suspend msg;
    msg.what = ant::window::suspend::did_resume;
    ant::window::input_message(g_peekL, msg);
}
- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return UIInterfaceOrientationMaskLandscape;
}
@end

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

static bool peekmessage() {
    lua_State* L = g_messageL;
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
    g_messageL = L;
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

static void window_set_maxfps(float fps) {
    //TODO
    //if (global_window) {
    //    [global_window maxfps: fps];
    //}
}

void ant::window::set_message(ant::window::set_msg& msg) {
	switch (msg.type) {
	case ant::window::set_msg::type::maxfps:
		window_set_maxfps(msg.maxfps);
		break;
	default:
		break;
	}
}

static int lua_traceback(lua_State *L) {
	const char* msg = lua_tostring(L, 1);
	if (msg == NULL && !lua_isnoneornil(L, 1)) {
		lua_pushvalue(L, 1);
	} else {
		luaL_traceback(L, L, msg, 2);
	}
	return 1;
}

static int lmainloop(lua_State* L) {
    lua_createtable(L, 2, 0);
    g_peekL = lua_newthread(L);
    lua_seti(L, -2, 1);
    g_callbackL = lua_newthread(L);
    lua_seti(L, -2, 2);
    lua_setfield(L, LUA_REGISTRYINDEX, "ANT_WINDOW_MESSAGE_IOS");

    lua_pushcfunction(g_callbackL, lua_traceback);
    lua_pushvalue(L, 1);
    lua_xmove(L, g_callbackL, 1);

    window_message_set_fetch_func(MessageFetch);

    int argc = 0;
    char **argv = 0;
    UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
	return 0;
}

extern "C"
int luaopen_window_ios(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "mainloop", lmainloop },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
