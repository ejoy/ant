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

int run_func_f;

void HandleError(const char* err_msg)
{
    printf("function have error %s\n", err_msg);
    NSString* err_str = [NSString stringWithUTF8String:err_msg];
    
    NSString* sand_box = [NSHomeDirectory() stringByAppendingString:@"/Documents/err.txt"];
    NSFileHandle* file_handle = [NSFileHandle fileHandleForWritingAtPath:sand_box];
    [file_handle seekToEndOfFile];
    [file_handle writeData:[err_str dataUsingEncoding:NSUTF8StringEncoding]];
    [file_handle closeFile];
    
    //force quit
    exit(EXIT_FAILURE);
}

@implementation FrameWork

-(void) InitFrameWork:(CALayer *)layer size:(CGSize)view_size {
    NSString* app_path = [[NSBundle mainBundle] resourcePath] ;
    NSString* sand_box = NSHomeDirectory();
    
    const char* app_path_char = [app_path UTF8String];
    const char* sand_box_path = [sand_box UTF8String];
    
    //only used for self updating
    struct luavm* su_v = luavm_new();
    NSString* fw_su_path = [app_path stringByAppendingString:@"/fw/fw_selfupdate.lua"];
    NSString* su_string = [NSString stringWithContentsOfFile:fw_su_path encoding:NSUTF8StringEncoding error:nil];
    const char* err_msg = luavm_init(su_v, [su_string UTF8String], "fss", get_cfuncs, app_path_char, sand_box_path);
    if(err_msg){
        HandleError(err_msg);
        return;
    }
    
    luavm_close(su_v);

    
    V = luavm_new();
    NSString* preload_path = [app_path stringByAppendingString:@"/fw/fw_preload.lua"];
    NSString* init_file = [NSString stringWithContentsOfFile:preload_path encoding:NSUTF8StringEncoding error:nil];
    
    //init stuff
    err_msg = luavm_init(V, [init_file UTF8String], "fss", get_cfuncs, app_path_char, sand_box_path);
    if(err_msg) {
        HandleError(err_msg);
        return;
    }
    
    //register function
    NSString* run_path = [app_path stringByAppendingString:@"/fw/fw_run.lua"];
    NSString* run_file = [NSString stringWithContentsOfFile:run_path encoding:NSUTF8StringEncoding error:nil];
    
    err_msg = luavm_register(V, [run_file UTF8String], "=runfile", &run_func_f);
    if(err_msg){
        HandleError(err_msg);
        return;
    }
    
    err_msg = luavm_call(V, run_func_f, "spnnss", "/libs/fw/fw_start.lua", layer, view_size.width, view_size.height, app_path_char, sand_box_path);
    if(err_msg){
        HandleError(err_msg);
        return;
    }
}

-(void) Update {
    //call registed update function
    const char* err_msg = luavm_call(V, run_func_f, "s", "/libs/fw/fw_update.lua");
    if(err_msg){
        HandleError(err_msg);
        return;
    }
    
}

-(void) Terminate {
    //call registed terminate function
    const char* err_msg = luavm_call(V, run_func_f, "s", "/libs/fw/fw_terminate.lua");
    if(err_msg){
        HandleError(err_msg);
        return;
    }
    
    if(V) {
        luavm_close(V);
    }
}


@end
