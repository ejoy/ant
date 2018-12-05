#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <ant.h>

@interface ViewController : UIViewController
@end
@implementation ViewController
- (BOOL)prefersStatusBarHidden {
    return YES;
}
@end

static id<MTLDevice> m_device = NULL;

@interface View : UIView
@property (nonatomic, retain) CADisplayLink* m_displayLink;
@end
@implementation View
+ (Class)layerClass  {
    Class metalClass = NSClassFromString(@"CAMetalLayer");
    if (metalClass != nil)  {
        m_device = MTLCreateSystemDefaultDevice();
        if (m_device) {
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
    self.backgroundColor = [UIColor yellowColor];
    
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    ant_searcher_init(L, false);

    {
        if (luaL_dostring(L, "return 'Hello ' .. _VERSION") == LUA_OK) {
        }
        const char* result = lua_tostring(L, -1);
        UILabel *labelView = [[UILabel alloc] initWithFrame:CGRectMake(100,200,800,50)];
        labelView.text = @(result);
        labelView.textColor = [UIColor blackColor];
        [self addSubview:labelView];
    }
    
    {
        NSString* nsMainLua = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"main.lua"];
        //NSString* nsPersonPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        //NSString* nsMainLua = [nsPersonPath stringByAppendingPathComponent:@"main.lua"];
        if (luaL_dofile(L, [nsMainLua cStringUsingEncoding:NSUTF8StringEncoding]) == LUA_OK) {
        }
        const char* result = lua_tostring(L, -1);
        UILabel *labelView = [[UILabel alloc] initWithFrame:CGRectMake(100,300,800,50)];
        labelView.text = @(result);
        labelView.textColor = [UIColor blackColor];
        [self addSubview:labelView];
        lua_close(L);
    }
    
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

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, retain) UIWindow* m_window;
@property (nonatomic, retain) View*     m_view;
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

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
