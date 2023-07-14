#include "../../window.h"

#import <UIKit/UIKit.h>

extern UIView* global_window;
extern struct ant_window_callback* g_cb;

static int getState(UIGestureRecognizerState v) {
    switch (v) {
    case UIGestureRecognizerStateBegan:
        return 0;
    case UIGestureRecognizerStateChanged:
        return 1;
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled:
        return 2;
    case UIGestureRecognizerStatePossible:
    case UIGestureRecognizerStateFailed:
    default:
        return -1;
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
    CGPoint pan_last;
}
@end
@implementation LuaGestureHandler
-(void)handleTap:(UITapGestureRecognizer *)gesture {
    auto pt = getLocationInView(gesture);
    struct ant::window::msg_gesture_tap msg;
    msg.x = pt.x;
    msg.y = pt.y;
    ant::window::input_message(g_cb, msg);
}
-(void)handlePinch:(UIPinchGestureRecognizer *)gesture {
    int state = getState(gesture.state);
    if (state < 0) {
        return;
    }
    auto pt = getLocationOfTouch(gesture);
    struct ant::window::msg_gesture_pinch msg;
    msg.state = getState(gesture.state);
    msg.x = pt.x;
    msg.y = pt.y;
    msg.velocity = gesture.velocity;
    ant::window::input_message(g_cb, msg);
}
-(void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    auto pt = getLocationInView(gesture);
    struct ant::window::msg_gesture_longpress msg;
    msg.x = pt.x;
    msg.y = pt.y;
    ant::window::input_message(g_cb, msg);
}
-(void)handlePan:(UIPanGestureRecognizer *)gesture {
    int state = getState(gesture.state);
    if (state < 0) {
        return;
    }
    auto pt = getLocationInView(gesture);
    msg.state = getState(gesture.state);
    msg.x = pt.x;
    msg.y = pt.y;
    if (state == 0) {
        msg.dx = 0;
        msg.dy = 0;
    }
    else {
        msg.dx = pt.x - pan_last.x;
        msg.dy = pt.y - pan_last.y;
    }
    ant::window::input_message(g_cb, msg);
    pan_last = pt;
}
@end

id init_gesture() {
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
