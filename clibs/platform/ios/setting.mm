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
    NSString* value = [defaults objectForKey:[NSString stringWithUTF8String:key]];
    if (value) {
        lua_pushstring(L, [value UTF8String]);
        return 1;
    }
    return 0;
}

static int set(lua_State* L) {
    const char* key = luaL_checkstring(L, 1);
    const char* value = luaL_checkstring(L, 2);
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSString stringWithUTF8String:value] forKey:[NSString stringWithUTF8String:key]];
    [defaults synchronize];
    return 0;
}

int lsetting(lua_State* L) {
    if (lua_gettop(L) == 1) {
        return get(L);
    }
    return set(L);
}
