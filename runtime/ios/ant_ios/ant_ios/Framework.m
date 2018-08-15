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

static void err_handle(struct luavm *V) {
    printf("error: %s\n", luavm_lasterror(V));
}

-(void) InitFrameWork:(CALayer *)layer size:(CGSize)view_size {
    NSString* app_path = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/fw"] ;
    NSString* sand_box = NSHomeDirectory();
    
    const char* app_path_char = [app_path UTF8String];
    const char* sand_box_path = [sand_box UTF8String];
    
    
    NSString* fw_init_path = [app_path stringByAppendingString:@"/fw_init.lua"];
    
    NSString* init_string = [NSString stringWithContentsOfFile:fw_init_path encoding:NSUTF8StringEncoding error:nil];
    V = luavm_new();
    
    //init stuff
    if(luavm_init(V, [init_string UTF8String], "fs", get_cfuncs, app_path_char)){
        err_handle(V);
    }
    
    //register function
    NSString* fs_start_path = [app_path stringByAppendingString:@"/fw_start.lua"];
    NSString* start_string = [NSString stringWithContentsOfFile:fs_start_path encoding:NSUTF8StringEncoding error:nil];
    
    init_f = luavm_register(V, [start_string UTF8String],"@fw_start.lua");
    if(init_f == 0){
        err_handle(V);
    }
    
    NSString* fs_update_path = [app_path stringByAppendingString:@"/fw_update.lua"];
    NSString* update_string = [NSString stringWithContentsOfFile:fs_update_path encoding:NSUTF8StringEncoding error:nil];
    
    update_f = luavm_register(V, [update_string UTF8String],"@fw_update.lua");
    if(update_f == 0){
        err_handle(V);
    }
    
    NSString* fs_terminate_path = [app_path stringByAppendingString:@"/fw_terminate.lua"];
    NSString* terminate_string = [NSString stringWithContentsOfFile:fs_terminate_path encoding:NSUTF8StringEncoding error:nil];
    
    terminate_f = luavm_register(V, [terminate_string UTF8String], "@fw_terminate.lua");
    if(terminate_f == 0){
        err_handle(V);
    }
    
    if(luavm_call(V, init_f, "pnnss", layer, view_size.width, view_size.height, app_path_char, sand_box_path)){
        err_handle(V);
    }
}

-(void) Update {
    //call registed update function
    if(luavm_call(V, update_f, NULL)) {
        err_handle(V);
    }
    
}

-(void) Terminate {
    //call registed terminate function
    if(V) {
        luavm_close(V);
    }
}


@end
