#include "ios_error.h"
#import <UIKit/UIKit.h>
#include <execinfo.h>

const char* errmsg = 0;

@interface ErrorViewController : UIViewController
@end
@implementation ErrorViewController
- (BOOL)prefersStatusBarHidden {
    return YES;
}
@end

@interface ErrorApp : UIResponder <UIApplicationDelegate>
@property (nonatomic, retain) UIWindow* m_window;
@property (nonatomic, retain) UIView*   m_view;
@end
@implementation ErrorApp
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    CGRect rect = [[UIScreen mainScreen] bounds];
    self.m_window = [[UIWindow alloc] initWithFrame: rect];
    self.m_view = [[UIView alloc] initWithFrame: rect];
    self.m_view.backgroundColor = [UIColor blueColor];
    UILabel *labelView = [[UILabel alloc] initWithFrame:CGRectMake(1,1,0,0)];
    labelView.text = @(errmsg);
    labelView.textColor = [UIColor whiteColor];
    
    labelView.numberOfLines = 0;
    labelView.frame = rect;
    [labelView sizeToFit];
    [self.m_view addSubview:labelView];
    [self.m_window addSubview: self.m_view];
    
    ErrorViewController* mvc = [[ErrorViewController alloc] init];
    mvc.view = self.m_view;
    [self.m_window setRootViewController: mvc];
    [self.m_window makeKeyAndVisible];
    float scaleFactor = [[UIScreen mainScreen] scale];
    [self.m_view setContentScaleFactor: scaleFactor];
    return YES;
}
@end

void ios_error_display(const char* em) {
    printf("[Lua Error]:%s\n", em);
    errmsg = em;
    char* argv[] = {""};
    UIApplicationMain(0, argv, nil, NSStringFromClass([ErrorApp class]));
}

static int writelog(const char* msg) {
    NSArray* array = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if ([array count] <= 0) {
        return 1;
    }
    char path[256];
    const char* dir = [[array objectAtIndex:0] fileSystemRepresentation];
    snprintf(path, 256, "%s/exception.log", dir);
    FILE* f = fopen(path, "w");
    if (!f) {
        return 1;
    }
    fputs(msg, f);
    fclose(f);
    return 0;
}

static void signal_handler(int sn) {
    signal(sn, SIG_DFL);
    NSMutableString* info = [[NSMutableString alloc] init];
    [info appendString:@"Stack:\n"];
    void* callstack[128];
    int i, frames = backtrace(callstack, 128);
    char** strs = backtrace_symbols(callstack, frames);
    for (i = 0; i <frames; ++i) {
        [info appendFormat:@"%s\n", strs[i]];
    }
    free(strs);
    writelog([info UTF8String]);
}

static void exception_handle(NSException* exception) {
    NSSetUncaughtExceptionHandler(0);
    NSArray*  stackArray = [exception callStackSymbols];
    NSString* reason = [exception reason];
    NSString* name = [exception name];
    NSString* info = [NSString stringWithFormat:@"Exception reason：%@\nException name：%@\nException stack：%@", name, reason, stackArray];
    writelog([info UTF8String]);
}

void ios_error_handler(void) {
    signal(SIGABRT, signal_handler);
    signal(SIGILL, signal_handler);
    signal(SIGSEGV, signal_handler);
    signal(SIGFPE, signal_handler);
    signal(SIGBUS, signal_handler);
    signal(SIGPIPE, signal_handler);
    NSSetUncaughtExceptionHandler(&exception_handle);
}
