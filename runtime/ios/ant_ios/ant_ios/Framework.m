//
//  Framework.m
//  ant_ios
//
//  Created by ejoy on 2018/8/9.
//  Copyright © 2018年 ejoy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Framework.h"
#import "preload.h"

struct luavm* V;

int init_f;
int update_f;
int terminate_f;

@implementation FrameWork

-(void) InitFrameWork:(CALayer *)layer size:(CGSize)view_size {
    NSString* app_path = [[NSBundle mainBundle] resourcePath] ;
    NSString* sand_box = NSHomeDirectory();
    
    const char* app_path_char = [app_path UTF8String];
    const char* sand_box_path = [sand_box UTF8String];
    
    
    NSString* fw_init_path = [app_path stringByAppendingString:@"/fw/fw_init.lua"];
    
    NSString* init_string = [NSString stringWithContentsOfFile:fw_init_path encoding:NSUTF8StringEncoding error:nil];
    V = luavm_new();
    
    //init stuff
    const char* err_msg = luavm_init(V, [init_string UTF8String], "fs", get_cfuncs, app_path_char);
    if(err_msg) {
        printf("init error: %s\n", err_msg);
        return;
    }
    
    //register function
    NSString* fs_start_path = [app_path stringByAppendingString:@"/fw/fw_start.lua"];
    NSString* start_string = [NSString stringWithContentsOfFile:fs_start_path encoding:NSUTF8StringEncoding error:nil];
    
    err_msg = luavm_register(V, [start_string UTF8String],"@fw_start.lua", &init_f);
    if(err_msg){
        printf("register start error: %s\n", err_msg);
        return;
    }
    
    NSString* fs_update_path = [app_path stringByAppendingString:@"/fw/fw_update.lua"];
    NSString* update_string = [NSString stringWithContentsOfFile:fs_update_path encoding:NSUTF8StringEncoding error:nil];
    
    err_msg = luavm_register(V, [update_string UTF8String],"@fw_update.lua", &update_f);
    if(err_msg){
        printf("register update error: %s\n", err_msg);
        return;
    }
    
    NSString* fs_terminate_path = [app_path stringByAppendingString:@"/fw/fw_terminate.lua"];
    NSString* terminate_string = [NSString stringWithContentsOfFile:fs_terminate_path encoding:NSUTF8StringEncoding error:nil];
    
    err_msg = luavm_register(V, [terminate_string UTF8String], "@fw_terminate.lua", &terminate_f);
    if(err_msg){
        printf("register terminate error: %s\n", err_msg);
        return;
    }
    
    err_msg = luavm_call(V, init_f, "pnnss", layer, view_size.width, view_size.height, app_path_char, sand_box_path);
    
    if(err_msg){
        printf("call init function error: %s\n", err_msg);
        return;
    }
}

-(void) Update {
    //call registed update function
    const char* err_msg = luavm_call(V, update_f, NULL);
    
    if(err_msg){
        printf("call update function error: %s\n", err_msg);
        return;
    }
}

-(void) Terminate {
    //call registed terminate function
    const char* err_msg = luavm_call(V, terminate_f, NULL);
    if(err_msg){
        printf("call terminate function error: %s\n", err_msg);
        return;
    }
    
    if(V) {
        luavm_close(V);
    }
}


@end
