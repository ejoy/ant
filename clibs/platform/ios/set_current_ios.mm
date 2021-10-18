#include "set_current.h"
#include <lua.hpp>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#import <UIKit/UIKit.h>
#import "ios/NetReachability.h"

static void net_reachability() {
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

static int need_cleanup() {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* key = @"clean_up_next_time";
    id value = [defaults objectForKey:key];
    NSLog(@"key = %@, value = %@",key, value);
    
    if (value && [value intValue] == 1) {
        [defaults setObject:@"0" forKey:key];
        [defaults synchronize];
        return 1;
    }
    return 0;
}

static NSString* server_type() {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    id value = [defaults objectForKey:@"server_type"];
    NSLog(@"key = server_type, value = %@", value);
    return value;
}

static NSString* server_address() {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    id value = [defaults objectForKey:@"server_address"];
    NSLog(@"key = server_address, value = %@", value);
    return value;
}

int runtime_args(lua_State* L) {
    net_reachability();
    NSString* type = server_type();
    NSString* address = server_address();
    lua_pushboolean(L, need_cleanup()):
    lua_pushstring(L, type? [type UTF8String]: "usb");
    lua_pushstring(L, address? [address UTF8String]: "");
    return 3;
}
