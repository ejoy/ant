//
//  main.m
//  ServerMac
//
//  Created by ejoy on 2018/7/26.
//  Copyright © 2018年 ejoy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LuaRender.h"

int main(int argc, const char * argv[]) {
    LuaRender *lua_render = [[LuaRender alloc] init];
    [lua_render InitScript];
    
    while (true) {
        [lua_render Update];
    }
    
    return 0;
}
