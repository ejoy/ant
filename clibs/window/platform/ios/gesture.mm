#include "window.h"
#include "../../window.h"

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

@interface LuaGestureHandler : NSObject {
    CGPoint pan_began;
    CGPoint pan_last;
}
@end
@implementation LuaGestureHandler
-(void)handleTap:(UITapGestureRecognizer *)gesture {
    auto pt = getLocationInView(gesture);
    struct ant_gesture_tap msg;
    msg.x = pt.x;
    msg.y = pt.y;
    window_message_gesture(g_cb, msg);
}
-(void)handlePinch:(UIPinchGestureRecognizer *)gesture {
    int state = getState(gesture.state);
    if (state < 0) {
        return;
    }
    auto pt = getLocationInView(gesture);
    struct ant_gesture_pinch msg;
    msg.state = getState(gesture.state);
    msg.x = pt.x;
    msg.y = pt.y;
    msg.velocity = gesture.velocity;
    window_message_gesture(g_cb, msg);
}
-(void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    auto pt = getLocationInView(gesture);
    struct ant_gesture_longpress msg;
    msg.x = pt.x;
    msg.y = pt.y;
    window_message_gesture(g_cb, msg);
}
-(void)handlePan:(UIPanGestureRecognizer *)gesture {
    switch (gesture.state) {
        break;
    case UIGestureRecognizerStateBegan: {
        auto pt = getLocationInView(gesture);
        pan_last = pan_began = pt;
        break;
    }
    case UIGestureRecognizerStateChanged: {
        auto pt = getLocationInView(gesture);
        struct ant_gesture_pan msg;
        msg.x = pt.x;
        msg.y = pt.y;
        msg.dx = pt.x - pan_last.x;
        msg.dy = pt.y - pan_last.y;
        msg.vx = pt.x - pan_began.x;
        msg.vy = pt.y - pan_began.y;
        window_message_gesture(g_cb, msg);
        pan_last = pt;
        break;
    }
    case UIGestureRecognizerStatePossible:
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateFailed:
    default:
        break;
    }
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
