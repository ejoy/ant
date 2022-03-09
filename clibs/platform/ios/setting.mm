#include <lua.hpp>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#import <UIKit/UIKit.h>
#import "NetReachability.h"

void net_reachability() {
    NetReachability *reachability = [NetReachability reachabilityWithHostName:@"www.taobao.com"];
    NetReachWorkStatus netStatus = [reachability currentReachabilityStatus];
    switch (netStatus) {
    case NetReachWorkNotReachable: NSLog(@"网络不可用"); break;
    case NetReachWorkStatusUnknown: NSLog(@"未知网络"); break;
    case NetReachWorkStatusWWAN2G: NSLog(@"2G网络"); break;
    case NetReachWorkStatusWWAN3G: NSLog(@"3G网络"); break;
    case NetReachWorkStatusWWAN4G: NSLog(@"4G网络"); break;
    case NetReachWorkStatusWiFi: NSLog(@"WiFi"); break;
    default: break;
    }
}

static int get(lua_State* L) {
    const char* key = luaL_checkstring(L, 1);
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSObject* value = [defaults objectForKey:[NSString stringWithUTF8String:key]];
    if (!value) {
        return 0;
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString* v = (NSString*)value;
        lua_pushstring(L, [v UTF8String]);
        return 1;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber* v = (NSNumber*)value;
        if ([v isEqual:@(YES)]) {
            lua_pushboolean(L, 1);
            return 1;
        }
        if ([v isEqual:@(NO)]) {
            lua_pushboolean(L, 0);
            return 1;
        }
        //TODO integer
        lua_pushnumber(L, [v doubleValue]);
        return 1;
    }
    return luaL_error(L, "invalid setting type");
}

static int set(lua_State* L) {
    const char* key = luaL_checkstring(L, 1);
    NSObject* value;
    switch (lua_type(L, 2)) {
    case LUA_TSTRING:
        value = [NSString stringWithUTF8String:luaL_checkstring(L, 2)];
        break;
    case LUA_TBOOLEAN:
        if (lua_toboolean(L, 2)) {
            value = @(YES);
        }
        else {
            value = @(NO);
        }
        break;
    default:
        return luaL_error(L, "invalid setting type");
    }
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:value forKey:[NSString stringWithUTF8String:key]];
    [defaults synchronize];
    return 0;
}

int lsetting(lua_State* L) {
    if (lua_gettop(L) == 1) {
        return get(L);
    }
    return set(L);
}
