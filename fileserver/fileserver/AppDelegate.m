//
//  AppDelegate.m
//  fileserver
//
//  Created by ejoy on 2018/5/24.
//  Copyright © 2018年 ejoy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AppDelegate.h"
#import "ViewController.h"

@implementation View
@synthesize m_Render;
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)rect
{
    self = [super initWithFrame:rect];
    
    m_Render = [[LuaRender alloc] init];
    [m_Render SelfUpdate];
    
    CGSize view_size = rect.size;
    CALayer* layer = [self layer];
    [m_Render InitScript:layer size:view_size];
    
    if (nil == self)
    {
        return nil;
    }
    
    return self;
}

- (void)layoutSubviews
{
    
}

- (void)start
{
    if (nil == m_displayLink)
    {
        m_displayLink = [self.window.screen displayLinkWithTarget:self selector:@selector(renderFrame)];
        [m_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)stop
{
    [m_Render Terminate];
    
    if (nil != m_displayLink)
    {
        [m_displayLink invalidate];
        m_displayLink = nil;
    }
}

- (void)renderFrame
{
    [m_Render Update];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSArray* touch_array = [[event allTouches] allObjects];
    for (NSInteger i = 0; i < [touch_array count]; ++i) {
        UITouch* touch = touch_array[i];
        CGPoint touchLocation = [touch locationInView:self];
        touchLocation.x *= self.contentScaleFactor;
        touchLocation.y *= self.contentScaleFactor;
        
        [m_Render AddInputMessage:@"begin" x_pos:touchLocation.x y_pos:touchLocation.y];
    }
    
    /*
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint touchLocation = [touch locationInView:self];
    touchLocation.x *= self.contentScaleFactor;
    touchLocation.y *= self.contentScaleFactor;
    
    NSString *log = [NSString stringWithFormat:@"touches began x: %f, y: %f", touchLocation.x, touchLocation.y];
    [m_Render SendLog:log];
     */
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSArray* touch_array = [[event allTouches] allObjects];
    for (NSInteger i = 0; i < [touch_array count]; ++i) {
        UITouch* touch = touch_array[i];
        CGPoint touchLocation = [touch locationInView:self];
        touchLocation.x *= self.contentScaleFactor;
        touchLocation.y *= self.contentScaleFactor;
        
        [m_Render AddInputMessage:@"end" x_pos:touchLocation.x y_pos:touchLocation.y];
    }
    
    /*
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint touchLocation = [touch locationInView:self];
    touchLocation.x *= self.contentScaleFactor;
    touchLocation.y *= self.contentScaleFactor;
    
    NSString *log = [NSString stringWithFormat:@"touches ended x: %f, y: %f", touchLocation.x, touchLocation.y];
    [m_Render SendLog:log];
     */
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSArray* touch_array = [[event allTouches] allObjects];
    for (NSInteger i = 0; i < [touch_array count]; ++i) {
        UITouch* touch = touch_array[i];
        CGPoint touchLocation = [touch locationInView:self];
        touchLocation.x *= self.contentScaleFactor;
        touchLocation.y *= self.contentScaleFactor;
        
        [m_Render AddInputMessage:@"move" x_pos:touchLocation.x y_pos:touchLocation.y];
    }
    
    /*
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint touchLocation = [touch locationInView:self];
    touchLocation.x *= self.contentScaleFactor;
    touchLocation.y *= self.contentScaleFactor;
    
    NSString *log = [NSString stringWithFormat:@"touches moved x: %f, y: %f", touchLocation.x, touchLocation.y];
    [m_Render SendLog:log];
     */
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSArray* touch_array = [[event allTouches] allObjects];
    for (NSInteger i = 0; i < [touch_array count]; ++i) {
        UITouch* touch = touch_array[i];
        CGPoint touchLocation = [touch locationInView:self];
        touchLocation.x *= self.contentScaleFactor;
        touchLocation.y *= self.contentScaleFactor;
        
        [m_Render AddInputMessage:@"cancel" x_pos:touchLocation.x y_pos:touchLocation.y];
    }
    
    /*
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint touchLocation = [touch locationInView:self];
    touchLocation.x *= self.contentScaleFactor;
    touchLocation.y *= self.contentScaleFactor;
    
    NSString *log = [NSString stringWithFormat:@"touches cancelled x: %f, y: %f", touchLocation.x, touchLocation.y];
    [m_Render SendLog:log];
     */
}

@end

@implementation AppDelegate

@synthesize m_window;
@synthesize m_view;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{    
    CGRect rect = [ [UIScreen mainScreen] bounds];
    m_window = [ [UIWindow alloc] initWithFrame: rect];
    m_view = [ [View alloc] initWithFrame: rect];
    
    [m_view setBackgroundColor:([UIColor colorWithRed:0 green:0 blue:0 alpha:0])];
   // [m_window addSubview: m_view];
    
    UIViewController *viewController = [[ViewController alloc] init];
    viewController.view = m_view;
    
    [m_window setRootViewController:viewController];
    [m_window makeKeyAndVisible];
    
  //  float scaleFactor = [[UIScreen mainScreen] scale];
  //  [m_view setContentScaleFactor: scaleFactor ];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    [m_view stop];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{

}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
 
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [m_view start];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [m_view stop];
}

- (void)dealloc
{
}

@end
