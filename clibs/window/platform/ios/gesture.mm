#include <lua.hpp>
#include "window.h"
#include "../../window.h"

static void setState(lua_State* L, UIGestureRecognizerState v) {
    switch (v) {
    case UIGestureRecognizerStateBegan:
        lua_pushstring(L, "began");
        break;
    case UIGestureRecognizerStateChanged:
        lua_pushstring(L, "changed");
        break;
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled:
        lua_pushstring(L, "ended");
        break;
    case UIGestureRecognizerStatePossible:
    case UIGestureRecognizerStateFailed:
    default:
        lua_pushstring(L, "unknown");
        break;
    }
}

static CGPoint setLocationInView(lua_State* L, UIGestureRecognizer* gesture) {
    CGPoint pt = [gesture locationInView:global_window];
    pt.x *= global_window.contentScaleFactor;
    pt.y *= global_window.contentScaleFactor;
    lua_pushnumber(L, static_cast<lua_Number>(pt.x));
    lua_setfield(L, -2, "x");
    lua_pushnumber(L, static_cast<lua_Number>(pt.y));
    lua_setfield(L, -2, "y");
    return pt;
}

static void setLocationOfTouch(lua_State* L, int idx, UIGestureRecognizer* gesture) {
    NSUInteger n = gesture.numberOfTouches;
    lua_createtable(L, static_cast<int>(n), 0);
    for (NSUInteger i = 0; i < n; ++i) {
        CGPoint pt = [gesture locationOfTouch:i inView:global_window];
        pt.x *= global_window.contentScaleFactor;
        pt.y *= global_window.contentScaleFactor;
        lua_createtable(L, 0, 2);
        lua_pushnumber(L, static_cast<lua_Number>(pt.x));
        lua_setfield(L, -2, "x");
        lua_pushnumber(L, static_cast<lua_Number>(pt.y));
        lua_setfield(L, -2, "y");
        lua_seti(L, -2, static_cast<lua_Integer>(i + 1));
    }
    lua_setfield(L, idx, "locationOfTouch");
}

@interface LuaGestureHandler : NSObject {
    CGPoint pan_began;
    CGPoint pan_last;
}
@end
@implementation LuaGestureHandler
-(void)handleTap:(UITapGestureRecognizer *)gesture {
    window_message(g_cb, [&](lua_State* L) {
        lua_pushstring(L, "gesture");
        lua_pushstring(L, "tap");
        lua_createtable(L, 0, 2);
        setLocationInView(L, gesture);
    });
}
-(void)handlePinch:(UIPinchGestureRecognizer *)gesture {
    switch (gesture.state) {
    case UIGestureRecognizerStateBegan:
    case UIGestureRecognizerStateChanged:
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled:
        window_message(g_cb, [&](lua_State* L) {
            lua_pushstring(L, "gesture");
            lua_pushstring(L, "pinch");
            lua_createtable(L, 0, 4);
            setLocationInView(L, gesture);
            setState(L, gesture.state);
            lua_setfield(L, -2, "state");
            lua_pushnumber(L, static_cast<lua_Number>(gesture.velocity));
            lua_setfield(L, -2, "velocity");
        });
        break;
    case UIGestureRecognizerStateFailed:
    case UIGestureRecognizerStatePossible:
    default:
        break;
    }
}
-(void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    window_message(g_cb, [&](lua_State* L) {
        lua_pushstring(L, "gesture");
        lua_pushstring(L, "long_press");
        lua_createtable(L, 0, 2);
        setLocationInView(L, gesture);
    });
}
-(void)handlePan:(UIPanGestureRecognizer *)gesture {
    switch (gesture.state) {
        break;
    case UIGestureRecognizerStateBegan: {
        CGPoint pt = [gesture locationInView:global_window];
        pt.x *= global_window.contentScaleFactor;
        pt.y *= global_window.contentScaleFactor;
        pan_last = pan_began = pt;
        break;
    }
    case UIGestureRecognizerStateChanged:
        window_message(g_cb, [&](lua_State* L) {
            lua_pushstring(L, "gesture");
            lua_pushstring(L, "pan");
            lua_createtable(L, 0, 6);
            CGPoint pt = [gesture locationInView:global_window];
            pt.x *= global_window.contentScaleFactor;
            pt.y *= global_window.contentScaleFactor;
            lua_pushnumber(L, static_cast<lua_Number>(pt.x));
            lua_setfield(L, -2, "x");
            lua_pushnumber(L, static_cast<lua_Number>(pt.y));
            lua_setfield(L, -2, "y");
            lua_pushnumber(L, static_cast<lua_Number>(pt.x - pan_began.x));
            lua_setfield(L, -2, "vx");
            lua_pushnumber(L, static_cast<lua_Number>(pt.y - pan_began.y));
            lua_setfield(L, -2, "vy");
            lua_pushnumber(L, static_cast<lua_Number>(pt.x - pan_last.x));
            lua_setfield(L, -2, "dx");
            lua_pushnumber(L, static_cast<lua_Number>(pt.y - pan_last.y));
            lua_setfield(L, -2, "dy");
            pan_last = pt;
        });
        break;
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
