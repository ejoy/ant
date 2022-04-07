#include <lua.hpp>
#include "ios/window.h"
#include <queue>
#include <mutex>

extern "C" {
#include <lua-seri.h>
}

static std::queue<void*> g_queue;
static std::mutex        g_mutex;

static void queue_push(void* data) {
    std::unique_lock<std::mutex> _(g_mutex);
    g_queue.push(data);
}

static void* queue_pop() {
    std::unique_lock<std::mutex> _(g_mutex);
    if (g_queue.empty()) {
        return NULL;
    }
    void* data = g_queue.front();
    g_queue.pop();
    return data;
}

static NSString* lua_nsstring(lua_State* L, int idx) {
    return [NSString stringWithUTF8String:lua_tostring(L, idx)];
}

static void lua_pushnsstring(lua_State* L, NSString* str) {
    lua_pushstring(L, [str UTF8String]);
}

static NSString* lua_getnsstring(lua_State* L, int idx, const char* field, NSString* def) {
    if (LUA_TSTRING != lua_getfield(L, idx, field)) {
        lua_pop(L, 1);
        return def;
    }
    NSString* r = lua_nsstring(L, -1);
    lua_pop(L, 1);
    return r;
}

static lua_Integer lua_getinteger(lua_State* L, int idx, const char* field, lua_Integer def) {
    if (LUA_TNUMBER != lua_getfield(L, idx, field)) {
        lua_pop(L, 1);
        return def;
    }
    if (!lua_isinteger(L, -1)) {
        lua_pop(L, 1);
        return def;
    }
    lua_Integer r = lua_tointeger(L, -1);
    lua_pop(L, 1);
    return r;
}

@interface LuaTapGesture : UITapGestureRecognizer {
    NSString* name;
}
@end
@implementation LuaTapGesture
@end

@interface LuaGestureHandler : NSObject {
    @public lua_State* L;
}
@end
@implementation LuaGestureHandler
-(void)handleTap:(LuaTapGesture *)gesture {
    lua_settop(L, 0);
    lua_pushnsstring(L, [gesture name]);
    CGPoint pt = [gesture locationInView:global_window];
    pt.x *= global_window.contentScaleFactor;
    pt.y *= global_window.contentScaleFactor;
    lua_pushnumber(L, pt.x);
    lua_pushnumber(L, pt.y);
    void* data = seri_pack(L, 0, NULL);
    queue_push(data);
}
@end

static void add_gesture(UIGestureRecognizer* gesture) {
    CFRunLoopPerformBlock([[NSRunLoop mainRunLoop] getCFRunLoop], kCFRunLoopCommonModes,
    ^{
        [global_window addGestureRecognizer:gesture];
    });
}

static int ltap(lua_State* L) {
    if (!global_window) {
        return luaL_error(L, "window not initialized.");
    }
    luaL_checktype(L, 1, LUA_TTABLE);
    id handler = (__bridge id)lua_touserdata(L, lua_upvalueindex(1));
    LuaTapGesture* gesture = [[LuaTapGesture alloc] initWithTarget:handler action:@selector(handleTap:)];
    gesture.name = lua_getnsstring(L, 1, "name", @"tap");
    gesture.numberOfTapsRequired = lua_getinteger(L, 1, "tap", 1);
    gesture.numberOfTouchesRequired = lua_getinteger(L, 1, "touch", 1);
    add_gesture(gesture);
    return 0;
}

static int levent(lua_State* L) {
    void* data = queue_pop();
    if (!data) {
        return 0;
    }
    return seri_unpackptr(L, data);
}

extern "C"
int luaopen_gesture(lua_State* L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        { "tap", ltap },
        { "event", levent },
        { NULL, NULL },
    };
    luaL_newlibtable(L, l);
    LuaGestureHandler* handler = [[LuaGestureHandler alloc] init];
    lua_pushlightuserdata(L, (__bridge_retained void*)handler);
    lua_newthread(L);
    handler->L = lua_tothread(L, -1);
    luaL_setfuncs(L, l, 2);
    return 1;
}
