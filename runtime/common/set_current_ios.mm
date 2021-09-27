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

static NSString* server() {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    id value = [defaults objectForKey:@"server"];
    NSLog(@"key = server, value = %@", value);
    return value;
}

int runtime_setcurrent(lua_State* L) {
    net_reachability();
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* docDir = [paths objectAtIndex:0];
    NSFileManager* fileMgr = [NSFileManager defaultManager];
    [fileMgr changeCurrentDirectoryPath:docDir];
    if (need_cleanup()) {
        [fileMgr removeItemAtPath:@".repo/" error:nil];
    }
    [fileMgr createDirectoryAtPath:@".repo/" withIntermediateDirectories:YES attributes:nil error:nil];
    for (int i = 0; i < 16; ++i) {
        for (int j = 0; j < 16; ++j) {
            NSString* dir = [NSString stringWithFormat:@".repo/%x%x", i, j];
            [fileMgr createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    return 0;
}

int runtime_args(lua_State* L) {
    NSString* address = server();
    if (!address) {
        return 0;
    }
    lua_pushstring(L, [address UTF8String]);
    return 1;
}
