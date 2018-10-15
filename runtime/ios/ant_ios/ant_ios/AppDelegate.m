//
//  AppDelegate.m
//  ant_ios
//
//  Created by ejoy on 2018/8/9.
//  Copyright © 2018年 ejoy. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"

@implementation View
@synthesize m_FrameWork;
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)rect{
    self = [super initWithFrame: rect];
    //init lua framework
    
    m_FrameWork = [[FrameWork alloc] init];
    
    CGSize view_size = rect.size;
    CALayer* layer = [self layer];
    [m_FrameWork InitFrameWork:layer size:view_size];
    
    if(nil == self) {
        return nil;
    }
    
    return self;
}

- (void) start {
    if(nil == m_DisplayLink)
    {
        m_DisplayLink = [self.window.screen displayLinkWithTarget:self selector:@selector(updateView)];
        [m_DisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void) updateView {
    //frame work update
    [m_FrameWork Update];
}

- (void) stop {
    [m_FrameWork Terminate];
    
    if(nil != m_DisplayLink) {
        [m_DisplayLink invalidate];
        m_DisplayLink = nil;
    }
}
//touch msg
@end

@implementation AppDelegate
@synthesize m_Window;
@synthesize m_View;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    CGRect rect = [[UIScreen mainScreen] bounds];
    m_Window = [[UIWindow alloc] initWithFrame:rect];
    m_View = [[View alloc] initWithFrame:rect];
    
    [m_View setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0]];
    
    UIViewController *vc = [[ViewController alloc] init];
    vc.view = m_View;
    
    [m_Window setRootViewController:vc];
    [m_Window makeKeyAndVisible];
    
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [m_View start];
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
